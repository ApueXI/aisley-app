part of 'account_controller.dart';

extension AccountControllerProfile on AccountController {
  Future<void> loadAccount() async {
    if (status == AccountStatus.loading) {
      return;
    }

    final operationEpoch = ++_operationEpoch;
    status = AccountStatus.loading;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    _notify();

    try {
      final loadedAccount = await _accountRepository.fetchAccount();
      if (operationEpoch != _operationEpoch) {
        return;
      }
      account = loadedAccount;
      status = AccountStatus.loaded;
      _onAccountUpdated?.call(loadedAccount);
      _notify();
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
    _notify();

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
      _notify();
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
      _notify();
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
}
