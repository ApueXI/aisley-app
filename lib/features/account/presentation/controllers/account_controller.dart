import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/account_repository.dart';
import '../../domain/account_models.dart';

part 'account_controller_profile.dart';
part 'account_controller_password.dart';
part 'account_controller_profile_photo.dart';
part 'account_controller_profile_photo_state.dart';
part 'account_controller_state.dart';

typedef AccountAuthFailureHandler = Future<void> Function(ApiException error);
typedef AccountUpdatedHandler = void Function(CourierAccount account);
typedef PasswordChangedHandler = Future<void> Function();

enum AccountStatus {
  idle,
  loading,
  loaded,
  savingProfile,
  changingPassword,
  validationError,
  forbidden,
  signedOut,
  retryableFailure,
  secureStorageFailure,
}

enum ProfilePhotoStatus {
  idle,
  loading,
  available,
  missing,
  uploading,
  deleting,
  validationError,
  forbidden,
  signedOut,
  retryableFailure,
  secureStorageFailure,
}

class AccountController extends ChangeNotifier {
  AccountController({
    required this._accountRepository,
    this._onAuthFailure,
    this._onPasswordChanged,
    this._onAccountUpdated,
  });

  final AccountRepository _accountRepository;
  final AccountAuthFailureHandler? _onAuthFailure;
  final PasswordChangedHandler? _onPasswordChanged;
  final AccountUpdatedHandler? _onAccountUpdated;
  int _operationEpoch = 0;

  AccountStatus status = AccountStatus.idle;
  CourierAccount? account;
  String? errorMessage;
  String? successMessage;
  Map<String, List<String>> fieldErrors = const <String, List<String>>{};
  ProfilePhotoStatus profilePhotoStatus = ProfilePhotoStatus.idle;
  ProfilePhotoData? profilePhoto;
  String? profilePhotoErrorMessage;
  String? profilePhotoSuccessMessage;
  Map<String, List<String>> profilePhotoFieldErrors =
      const <String, List<String>>{};

  bool get isBusy =>
      status == AccountStatus.loading ||
      status == AccountStatus.savingProfile ||
      status == AccountStatus.changingPassword ||
      profilePhotoStatus == ProfilePhotoStatus.uploading ||
      profilePhotoStatus == ProfilePhotoStatus.deleting;

  bool get isProfilePhotoBusy =>
      profilePhotoStatus == ProfilePhotoStatus.loading ||
      profilePhotoStatus == ProfilePhotoStatus.uploading ||
      profilePhotoStatus == ProfilePhotoStatus.deleting;

  void _notify() {
    notifyListeners();
  }
}

String _newIdempotencyKey([String prefix = 'courier-profile']) {
  return '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}';
}
