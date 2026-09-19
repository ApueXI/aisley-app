part of 'account_controller.dart';

extension AccountControllerPassword on AccountController {
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
    _notify();

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
      _notify();
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
}
