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

  AccountStatus status = AccountStatus.idle;
  CourierAccount? account;
  String? errorMessage;
  String? successMessage;
  Map<String, List<String>> fieldErrors = const <String, List<String>>{};

  bool get isBusy =>
      status == AccountStatus.loading ||
      status == AccountStatus.savingProfile ||
      status == AccountStatus.changingPassword;

  Future<void> loadAccount() async {
    if (status == AccountStatus.loading) {
      return;
    }

    status = AccountStatus.loading;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    notifyListeners();

    try {
      final loadedAccount = await _accountRepository.fetchAccount();
      account = loadedAccount;
      status = AccountStatus.loaded;
      _onAccountUpdated?.call(loadedAccount);
      notifyListeners();
    } on ApiException catch (error) {
      await _handleApiError(error);
    } on TokenStorageException {
      _setSecureStorageFailure();
    } on ApiContractException {
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
    if (status == AccountStatus.savingProfile ||
        status == AccountStatus.changingPassword) {
      return false;
    }

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
      account = updatedAccount;
      status = AccountStatus.loaded;
      successMessage = 'Your profile was updated.';
      _onAccountUpdated?.call(updatedAccount);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.isNetworkError && await _reconcileAfterUncertainProfileSave()) {
        return false;
      }
      await _handleApiError(error);
    } on TokenStorageException {
      _setSecureStorageFailure();
    } on ApiContractException {
      _setRetryableFailure(
        'The account service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<bool> _reconcileAfterUncertainProfileSave() async {
    try {
      final refreshedAccount = await _accountRepository.fetchAccount();
      account = refreshedAccount;
      status = AccountStatus.retryableFailure;
      errorMessage = 'The save result was uncertain. We refreshed your account; review the values before trying again.';
      successMessage = null;
      fieldErrors = const <String, List<String>>{};
      _onAccountUpdated?.call(refreshedAccount);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _handleApiError(error);
      return true;
    } on TokenStorageException {
      _setSecureStorageFailure();
      return true;
    } on ApiContractException {
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (status == AccountStatus.savingProfile ||
        status == AccountStatus.changingPassword) {
      return false;
    }

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
      account = null;
      await _onPasswordChanged?.call();
      status = AccountStatus.signedOut;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _handleApiError(error);
    } on TokenStorageException {
      _setSecureStorageFailure();
    } on ApiContractException {
      _setRetryableFailure(
        'The account service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }

  Future<void> retry() {
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

  void clear() {
    if (account == null &&
        status == AccountStatus.idle &&
        errorMessage == null &&
        successMessage == null &&
        fieldErrors.isEmpty) {
      return;
    }

    account = null;
    status = AccountStatus.idle;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    notifyListeners();
  }

  Future<void> _handleApiError(ApiException error) async {
    if (error.statusCode == 401 || error.statusCode == 403) {
      account = null;
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

  String _messageForError(ApiException error) {
    return switch (error.code) {
      'THROTTLED' => _throttledMessage(error),
      'VALIDATION_ERROR' => 'Check the highlighted fields and try again.',
      _ when error.isNetworkError =>
        'Could not reach the service. Check your connection and retry.',
      _ => 'We could not update your account. Please retry.',
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

String _newIdempotencyKey() {
  return 'courier-profile-${DateTime.now().toUtc().microsecondsSinceEpoch}';
}
