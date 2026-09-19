part of 'account_controller.dart';

extension AccountControllerState on AccountController {
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
    _notify();
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
      _notify();
      return;
    }

    fieldErrors = error.fieldErrors;
    status = error.statusCode == 422
        ? AccountStatus.validationError
        : AccountStatus.retryableFailure;
    errorMessage = _messageForError(error);
    successMessage = null;
    _notify();
  }

  void _setRetryableFailure(String message) {
    status = AccountStatus.retryableFailure;
    errorMessage = message;
    successMessage = null;
    _notify();
  }

  void _setSecureStorageFailure() {
    status = AccountStatus.secureStorageFailure;
    errorMessage =
        'Secure session storage is unavailable. Your account was not changed.';
    successMessage = null;
    _notify();
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
