part of 'auth_controller.dart';

extension AuthControllerState on AuthController {
  Future<void> handleAccountAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handlePickupAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handleDeliveryAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handleHistoryAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handleVehicleAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handleNotificationAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handleChatAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> handlePasswordChanged() {
    return _clearTokenAndBecomeSignedOut(
      message: 'Your password was changed. Please sign in again.',
    );
  }

  void updateIdentityFromAccount(CourierAccount account) {
    if (status != AuthStatus.authenticated) {
      return;
    }
    courier = account.toCourierIdentity();
    _notify();
  }

  Future<void> _handleAuthError(
    ApiException error, {
    bool fromSession = false,
  }) async {
    if (error.statusCode == 401) {
      _invalidateDashboardRequest();
      await _clearTokenAndBecomeSignedOut(
        message: fromSession ? null : 'Your session is no longer valid.',
      );
      return;
    }

    if (error.statusCode == 403 && error.code == 'POLICY_CONSENT_REQUIRED') {
      _preserveSessionForPolicyConsent(error);
      return;
    }

    if (error.statusCode == 403) {
      await _clearTokenAndSetBlocked(error);
      return;
    }

    if (fromSession && error.isNetworkError) {
      _invalidateDashboardRequest();
      status = AuthStatus.recoverableNetworkFailure;
      errorMessage = _messageForAuthError(error);
      retryAfter = null;
      isSigningOut = false;
      _notify();
      return;
    }

    _invalidateDashboardRequest();
    status = AuthStatus.signedOut;
    errorMessage = _messageForAuthError(error);
    retryAfter = error.retryAfter;
    isSigningOut = false;
    _notify();
  }

  Future<void> _clearTokenAndBecomeSignedOut({String? message}) async {
    try {
      await _authRepository.clearStoredToken();
      _becomeSignedOut(message: message);
    } on TokenStorageException {
      _becomeStorageFailure();
    }
  }

  Future<void> _clearTokenAndSetBlocked(ApiException error) async {
    _invalidateDashboardRequest();
    try {
      await _authRepository.clearStoredToken();
      final blockedStatus = _blockedStatusFor(error.code);
      status = blockedStatus;
      courier = null;
      dashboard = null;
      dashboardStatus = DashboardLoadStatus.idle;
      errorMessage = _messageForAuthError(error);
      isSigningOut = false;
      _onSessionEnded?.call();
      _notify();
    } on TokenStorageException {
      _becomeStorageFailure();
    }
  }

  void _preserveSessionForPolicyConsent(ApiException error) {
    _invalidateDashboardRequest();
    status = AuthStatus.policyConsentRequired;
    dashboard = null;
    dashboardStatus = DashboardLoadStatus.idle;
    dashboardErrorMessage = null;
    errorMessage = _messageForAuthError(error);
    retryAfter = null;
    isSigningOut = false;
    _notify();
  }

  void _becomeSignedOut({String? message}) {
    _invalidateDashboardRequest();
    status = AuthStatus.signedOut;
    courier = null;
    dashboard = null;
    dashboardStatus = DashboardLoadStatus.idle;
    dashboardErrorMessage = null;
    errorMessage = message;
    retryAfter = null;
    isSigningOut = false;
    _onSessionEnded?.call();
    _notify();
  }

  void _becomeStorageFailure() {
    _becomeStorageSafeFailure(
      'Secure session storage is unavailable. Your session was not changed.',
    );
  }

  void _becomeContractFailure(String message) {
    status = AuthStatus.recoverableNetworkFailure;
    errorMessage = message;
    isSigningOut = false;
    _notify();
  }

  void _becomeStorageSafeFailure(String message) {
    _invalidateDashboardRequest();
    status = AuthStatus.secureStorageFailure;
    courier = null;
    dashboard = null;
    errorMessage = message;
    isSigningOut = false;
    _onSessionEnded?.call();
    _notify();
  }

  AuthStatus _blockedStatusFor(String code) {
    return switch (code) {
      'ACCOUNT_PENDING_APPROVAL' => AuthStatus.pendingApproval,
      'ACCOUNT_REJECTED' => AuthStatus.rejected,
      'ACCOUNT_SUSPENDED' ||
      'ACCOUNT_INACTIVE' => AuthStatus.suspendedOrDeactivated,
      'LOGISTICS_ASSOCIATION_INVALID' => AuthStatus.invalidAffiliation,
      _ => AuthStatus.accessDenied,
    };
  }

  String _messageForAuthError(ApiException error) {
    return switch (error.code) {
      'INVALID_CREDENTIALS' => 'The email or password is incorrect.',
      'ACCOUNT_PENDING_APPROVAL' =>
        'Your Courier application is awaiting Logistics approval.',
      'ACCOUNT_REJECTED' => 'Your Courier application was not approved.',
      'ACCOUNT_SUSPENDED' => 'Your Courier account is suspended. Contact your Logistics organization.',
      'ACCOUNT_INACTIVE' => 'Your Courier account is inactive.',
      'LOGISTICS_ASSOCIATION_INVALID' =>
        'Your Logistics affiliation is not currently valid.',
      'FORBIDDEN_ROLE' => 'This account is not authorized as a Courier.',
      'FORBIDDEN' =>
        'This Courier account is not currently allowed to sign in.',
      'POLICY_CONSENT_REQUIRED' => 'Review and accept the current Terms of Service and Privacy Policy to continue.',
      'THROTTLED' => 'Too many attempts. Please wait and try again.',
      _ when error.isNetworkError =>
        'Could not reach the service. Check your connection and retry.',
      _ => 'We could not complete sign-in. Please try again.',
    };
  }
}
