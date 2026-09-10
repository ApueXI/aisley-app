import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

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

  Future<void> loadAccount() async {
    if (status == AccountStatus.loading) {
      return;
    }

    final operationEpoch = ++_operationEpoch;
    status = AccountStatus.loading;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    notifyListeners();

    try {
      final loadedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return;
      }
      account = loadedAccount;
      status = AccountStatus.loaded;
      _onAccountUpdated?.call(loadedAccount);
      notifyListeners();
      await loadProfilePhoto();
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return;
      }
      await _handleApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return;
      }
      _setSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return;
      }
      _setRetryableFailure(
        'The account service returned an unexpected response. Please retry.',
      );
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
  }) async {
    if (isBusy) {
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    status = AccountStatus.savingProfile;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    notifyListeners();

    try {
      final updatedAccount = await _accountRepository.updateProfile(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        contactNumber: contactNumber,
        idempotencyKey: _newIdempotencyKey(),
      );
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      account = updatedAccount;
      status = AccountStatus.loaded;
      successMessage = 'Your profile was updated.';
      _onAccountUpdated?.call(updatedAccount);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.isNetworkError &&
          await _reconcileAfterUncertainProfileSave(operationEpoch)) {
        return false;
      }
      await _handleApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setRetryableFailure(
        'The account service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> _reconcileAfterUncertainProfileSave(int operationEpoch) async {
    try {
      final refreshedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      account = refreshedAccount;
      status = AccountStatus.retryableFailure;
      errorMessage = 'The save result was uncertain. We refreshed your account; review the values before trying again.';
      successMessage = null;
      fieldErrors = const <String, List<String>>{};
      _onAccountUpdated?.call(refreshedAccount);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      await _handleApiError(error);
      return true;
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setSecureStorageFailure();
      return true;
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (isBusy) {
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    status = AccountStatus.changingPassword;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    notifyListeners();

    try {
      await _accountRepository.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      account = null;
      profilePhoto = null;
      profilePhotoStatus = ProfilePhotoStatus.idle;
      _clearProfilePhotoMessages();
      await _onPasswordChanged?.call();
      status = AccountStatus.signedOut;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      await _handleApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setRetryableFailure(
        'The account service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<void> loadProfilePhoto() async {
    final operationEpoch = ++_operationEpoch;
    await _loadProfilePhoto(
      clearMessages: true,
      operationEpoch: operationEpoch,
    );
  }

  Future<bool> _loadProfilePhoto({
    required bool clearMessages,
    required int operationEpoch,
  }) async {
    if (operationEpoch != _operationEpoch) {
      return false;
    }
    final currentAccount = account;
    if (currentAccount == null) {
      profilePhoto = null;
      profilePhotoStatus = ProfilePhotoStatus.idle;
      _clearProfilePhotoMessages();
      notifyListeners();
      return false;
    }

    final photoUrl = currentAccount.profile.profilePhotoUrl;
    if (photoUrl == null || photoUrl.trim().isEmpty) {
      profilePhoto = null;
      profilePhotoStatus = ProfilePhotoStatus.missing;
      _clearProfilePhotoMessages();
      notifyListeners();
      return false;
    }

    if (clearMessages) {
      _clearProfilePhotoMessages();
    } else {
      profilePhotoErrorMessage = null;
      profilePhotoFieldErrors = const <String, List<String>>{};
    }
    profilePhotoStatus = ProfilePhotoStatus.loading;
    notifyListeners();

    try {
      final loadedPhoto = await _accountRepository.fetchProfilePhoto(photoUrl);
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (loadedPhoto.bytes.isEmpty) {
        throw const ApiContractException('account.profile_photo.body');
      }
      profilePhoto = loadedPhoto;
      profilePhotoStatus = ProfilePhotoStatus.available;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.statusCode == 404) {
        profilePhoto = null;
        profilePhotoStatus = ProfilePhotoStatus.missing;
        profilePhotoErrorMessage = null;
        profilePhotoFieldErrors = const <String, List<String>>{};
        notifyListeners();
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The profile photo service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> uploadProfilePhoto(
    ProfilePhotoSelection selection, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (isBusy || account == null) {
      return false;
    }
    if (!account!.security.profilePhotoEditable) {
      profilePhotoStatus = ProfilePhotoStatus.forbidden;
      profilePhotoErrorMessage =
          'Profile photo changes are not available for this account.';
      profilePhotoSuccessMessage = null;
      notifyListeners();
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    profilePhotoStatus = ProfilePhotoStatus.uploading;
    profilePhotoErrorMessage = null;
    profilePhotoSuccessMessage = null;
    profilePhotoFieldErrors = const <String, List<String>>{};
    notifyListeners();

    try {
      final updatedAccount = await _accountRepository.uploadProfilePhoto(
        selection: selection,
        idempotencyKey: _newIdempotencyKey('courier-profile-photo'),
        onCancel: onCancel,
      );
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      account = updatedAccount;
      _onAccountUpdated?.call(updatedAccount);
      notifyListeners();

      final refreshed = await _loadProfilePhoto(
        clearMessages: false,
        operationEpoch: operationEpoch,
      );
      if (refreshed) {
        profilePhotoSuccessMessage = 'Your profile photo was updated.';
        notifyListeners();
        return true;
      }
      if (profilePhotoStatus == ProfilePhotoStatus.missing) {
        _setProfilePhotoRetryableFailure(
          'The upload completed, but the new photo could not be confirmed. Retry the photo refresh.',
        );
      }
      return false;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.isNetworkError &&
          await _reconcileAfterUncertainPhotoUpload(operationEpoch)) {
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The profile photo service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> _reconcileAfterUncertainPhotoUpload(int operationEpoch) async {
    try {
      final refreshedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      account = refreshedAccount;
      _onAccountUpdated?.call(refreshedAccount);

      final photoUrl = refreshedAccount.profile.profilePhotoUrl;
      if (photoUrl == null || photoUrl.trim().isEmpty) {
        profilePhoto = null;
        profilePhotoStatus = ProfilePhotoStatus.retryableFailure;
        profilePhotoErrorMessage = 'The upload result was uncertain. We refreshed your account; retry only after reviewing the current photo state.';
        profilePhotoSuccessMessage = null;
        profilePhotoFieldErrors = const <String, List<String>>{};
        notifyListeners();
        return true;
      }

      final confirmed = await _loadProfilePhoto(
        clearMessages: false,
        operationEpoch: operationEpoch,
      );
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      if (confirmed) {
        profilePhotoSuccessMessage = 'Your profile photo was updated.';
        notifyListeners();
        return true;
      }

      if (profilePhotoStatus != ProfilePhotoStatus.signedOut &&
          profilePhotoStatus != ProfilePhotoStatus.forbidden &&
          profilePhotoStatus != ProfilePhotoStatus.secureStorageFailure) {
        _setProfilePhotoRetryableFailure(
          'The upload result was uncertain. We refreshed your account, but could not confirm the private photo. Retry after reviewing the current state.',
        );
      }
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      await _handleProfilePhotoApiError(error);
      return true;
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoSecureStorageFailure();
      return true;
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoRetryableFailure(
        'The upload result was uncertain and could not be reconciled. Refresh your account before retrying.',
      );
      return true;
    }
  }

  Future<bool> deleteProfilePhoto() async {
    if (isBusy || account == null) {
      return false;
    }
    if (!account!.security.profilePhotoEditable) {
      profilePhotoStatus = ProfilePhotoStatus.forbidden;
      profilePhotoErrorMessage =
          'Profile photo changes are not available for this account.';
      profilePhotoSuccessMessage = null;
      notifyListeners();
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    profilePhotoStatus = ProfilePhotoStatus.deleting;
    profilePhotoErrorMessage = null;
    profilePhotoSuccessMessage = null;
    profilePhotoFieldErrors = const <String, List<String>>{};
    notifyListeners();

    try {
      await _accountRepository.deleteProfilePhoto();
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      return await _confirmProfilePhotoDeleted(operationEpoch);
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.statusCode == 404) {
        return await _confirmProfilePhotoDeleted(operationEpoch);
      }
      if (error.isNetworkError &&
          await _reconcileAfterUncertainPhotoDelete(operationEpoch)) {
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The profile photo service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> _confirmProfilePhotoDeleted(int operationEpoch) async {
    try {
      final refreshedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      account = refreshedAccount;
      _onAccountUpdated?.call(refreshedAccount);
      if (refreshedAccount.profile.profilePhotoUrl == null ||
          refreshedAccount.profile.profilePhotoUrl!.trim().isEmpty) {
        profilePhoto = null;
        profilePhotoStatus = ProfilePhotoStatus.missing;
        profilePhotoErrorMessage = null;
        profilePhotoSuccessMessage = 'Your profile photo was removed.';
        profilePhotoFieldErrors = const <String, List<String>>{};
        notifyListeners();
        return true;
      }

      profilePhotoStatus = profilePhoto == null
          ? ProfilePhotoStatus.retryableFailure
          : ProfilePhotoStatus.available;
      profilePhotoErrorMessage = 'The removal result was uncertain. We refreshed your account; the current photo is still present.';
      profilePhotoSuccessMessage = null;
      notifyListeners();
      return false;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      await _handleProfilePhotoApiError(error);
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setProfilePhotoRetryableFailure(
        'The removal result was uncertain. Refresh your account before retrying.',
      );
    }
    return false;
  }

  Future<bool> _reconcileAfterUncertainPhotoDelete(int operationEpoch) async {
    try {
      return await _confirmProfilePhotoDeleted(operationEpoch);
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      await _handleProfilePhotoApiError(error);
      return true;
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoSecureStorageFailure();
      return true;
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return true;
      }
      _setProfilePhotoRetryableFailure(
        'The removal result was uncertain and could not be reconciled. Refresh your account before retrying.',
      );
      return true;
    }
  }

  Future<void> retry() {
    if (account != null &&
        (profilePhotoStatus == ProfilePhotoStatus.retryableFailure ||
            profilePhotoStatus == ProfilePhotoStatus.validationError)) {
      return loadProfilePhoto();
    }
    if (status == AccountStatus.retryableFailure ||
        status == AccountStatus.validationError ||
        status == AccountStatus.loaded) {
      return loadAccount();
    }
    return Future<void>.value();
  }

  String? fieldError(String field) {
    final messages = fieldErrors[field];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.join(' ');
  }

  String? profilePhotoFieldError(String field) {
    final messages = profilePhotoFieldErrors[field];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.join(' ');
  }

  void clear() {
    _operationEpoch += 1;
    if (account == null &&
        status == AccountStatus.idle &&
        errorMessage == null &&
        successMessage == null &&
        fieldErrors.isEmpty &&
        profilePhoto == null &&
        profilePhotoStatus == ProfilePhotoStatus.idle &&
        profilePhotoErrorMessage == null &&
        profilePhotoSuccessMessage == null &&
        profilePhotoFieldErrors.isEmpty) {
      return;
    }

    account = null;
    status = AccountStatus.idle;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    profilePhoto = null;
    profilePhotoStatus = ProfilePhotoStatus.idle;
    _clearProfilePhotoMessages();
    notifyListeners();
  }

  Future<void> _handleApiError(ApiException error) async {
    if (error.statusCode == 401 || error.statusCode == 403) {
      account = null;
      profilePhoto = null;
      profilePhotoStatus = error.statusCode == 401
          ? ProfilePhotoStatus.signedOut
          : ProfilePhotoStatus.forbidden;
      _clearProfilePhotoMessages();
      errorMessage = error.statusCode == 401
          ? 'Your session is no longer valid. Please sign in again.'
          : 'This account is not currently eligible to use account management.';
      successMessage = null;
      fieldErrors = const <String, List<String>>{};
      await _onAuthFailure?.call(error);
      status = error.statusCode == 401
          ? AccountStatus.signedOut
          : AccountStatus.forbidden;
      notifyListeners();
      return;
    }

    fieldErrors = error.fieldErrors;
    status = error.statusCode == 422
        ? AccountStatus.validationError
        : AccountStatus.retryableFailure;
    errorMessage = _messageForError(error);
    successMessage = null;
    notifyListeners();
  }

  void _setRetryableFailure(String message) {
    status = AccountStatus.retryableFailure;
    errorMessage = message;
    successMessage = null;
    notifyListeners();
  }

  void _setSecureStorageFailure() {
    status = AccountStatus.secureStorageFailure;
    errorMessage =
        'Secure session storage is unavailable. Your account was not changed.';
    successMessage = null;
    notifyListeners();
  }

  Future<void> _handleProfilePhotoApiError(ApiException error) async {
    if (error.statusCode == 401 || error.statusCode == 403) {
      account = null;
      profilePhoto = null;
      profilePhotoStatus = error.statusCode == 401
          ? ProfilePhotoStatus.signedOut
          : ProfilePhotoStatus.forbidden;
      profilePhotoErrorMessage = error.statusCode == 401
          ? 'Your session is no longer valid. Please sign in again.'
          : 'This account is not currently eligible to manage a profile photo.';
      profilePhotoSuccessMessage = null;
      profilePhotoFieldErrors = const <String, List<String>>{};
      await _onAuthFailure?.call(error);
      status = error.statusCode == 401
          ? AccountStatus.signedOut
          : AccountStatus.forbidden;
      notifyListeners();
      return;
    }

    profilePhotoFieldErrors = error.fieldErrors;
    profilePhotoStatus = error.statusCode == 422
        ? ProfilePhotoStatus.validationError
        : ProfilePhotoStatus.retryableFailure;
    profilePhotoErrorMessage = _messageForProfilePhotoError(error);
    profilePhotoSuccessMessage = null;
    notifyListeners();
  }

  void _setProfilePhotoRetryableFailure(String message) {
    profilePhotoStatus = ProfilePhotoStatus.retryableFailure;
    profilePhotoErrorMessage = message;
    profilePhotoSuccessMessage = null;
    notifyListeners();
  }

  void _setProfilePhotoSecureStorageFailure() {
    profilePhotoStatus = ProfilePhotoStatus.secureStorageFailure;
    profilePhotoErrorMessage = 'Secure session storage is unavailable. Your profile photo was not changed.';
    profilePhotoSuccessMessage = null;
    notifyListeners();
  }

  void _clearProfilePhotoMessages() {
    profilePhotoErrorMessage = null;
    profilePhotoSuccessMessage = null;
    profilePhotoFieldErrors = const <String, List<String>>{};
  }

  String _messageForError(ApiException error) {
    return switch (error.code) {
      'THROTTLED' => _throttledMessage(error),
      'VALIDATION_ERROR' => 'Check the highlighted fields and try again.',
      _ when error.isNetworkError =>
        'Could not reach the service. Check your connection and retry.',
      _ => 'We could not update your account. Please retry.',
    };
  }

  String _messageForProfilePhotoError(ApiException error) {
    return switch (error.code) {
      'THROTTLED' => _throttledMessage(error),
      'VALIDATION_ERROR' =>
        'Choose a JPEG, JPG, PNG, or WebP image under 10 MB.',
      _ when error.isNetworkError => 'Could not reach the service. Check your connection and retry the photo operation.',
      _ => 'We could not update your profile photo. Please retry.',
    };
  }

  String _throttledMessage(ApiException error) {
    final retryAfter = error.retryAfter;
    if (retryAfter == null) {
      return 'Too many attempts. Please wait and try again.';
    }
    final seconds = retryAfter.inSeconds;
    return seconds <= 1
        ? 'Too many attempts. Try again in a moment.'
        : 'Too many attempts. Try again in $seconds seconds.';
  }
}

String _newIdempotencyKey([String prefix = 'courier-profile']) {
  return '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}';
}
