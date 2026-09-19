part of 'account_controller.dart';

extension AccountControllerProfilePhotoState on AccountController {
  String? profilePhotoFieldError(String field) {
    final messages = profilePhotoFieldErrors[field];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.join(' ');
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
      _notify();
      return;
    }

    profilePhotoFieldErrors = error.fieldErrors;
    profilePhotoStatus = error.statusCode == 422
        ? ProfilePhotoStatus.validationError
        : ProfilePhotoStatus.retryableFailure;
    profilePhotoErrorMessage = _messageForProfilePhotoError(error);
    profilePhotoSuccessMessage = null;
    _notify();
  }

  void _setProfilePhotoRetryableFailure(String message) {
    profilePhotoStatus = ProfilePhotoStatus.retryableFailure;
    profilePhotoErrorMessage = message;
    profilePhotoSuccessMessage = null;
    _notify();
  }

  void _setProfilePhotoSecureStorageFailure() {
    profilePhotoStatus = ProfilePhotoStatus.secureStorageFailure;
    profilePhotoErrorMessage = 'Secure session storage is unavailable. Your profile photo was not changed.';
    profilePhotoSuccessMessage = null;
    _notify();
  }

  void _clearProfilePhotoMessages() {
    profilePhotoErrorMessage = null;
    profilePhotoSuccessMessage = null;
    profilePhotoFieldErrors = const <String, List<String>>{};
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
}
