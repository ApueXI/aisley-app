part of 'auth_controller.dart';

extension AuthControllerSession on AuthController {
  Future<void> initialize() async {
    _invalidateDashboardRequest();
    status = AuthStatus.checkingSession;
    dashboard = null;
    dashboardStatus = DashboardLoadStatus.idle;
    dashboardErrorMessage = null;
    errorMessage = null;
    retryAfter = null;
    _notify();

    try {
      if (!await _authRepository.hasStoredToken()) {
        _becomeSignedOut();
        return;
      }

      courier = await _authRepository.currentCourier();
      status = AuthStatus.authenticated;
      _notify();
    } on ApiException catch (error) {
      await _handleAuthError(error, fromSession: true);
    } on TokenStorageException {
      _becomeStorageFailure();
    } on ApiContractException {
      _becomeContractFailure(
        'The service returned an unexpected account response.',
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (status == AuthStatus.authenticating) {
      return;
    }

    _invalidateDashboardRequest();
    status = AuthStatus.authenticating;
    errorMessage = null;
    retryAfter = null;
    courier = null;
    dashboard = null;
    dashboardStatus = DashboardLoadStatus.idle;
    dashboardErrorMessage = null;
    _onSessionEnded?.call();
    _notify();

    try {
      courier = await _authRepository.login(
        email: email,
        password: password,
        deviceName: AuthController._deviceName,
      );
      status = AuthStatus.authenticated;
      _notify();
    } on ApiException catch (error) {
      await _handleAuthError(error);
    } on TokenStorageException {
      _becomeStorageFailure();
    } on ApiContractException {
      await _clearTokenAndBecomeSignedOut(
        message: 'The service returned an unexpected sign-in response.',
      );
    }
  }

  Future<bool> signOut() async {
    if (isSigningOut) {
      return false;
    }

    _invalidateDashboardRequest();
    isSigningOut = true;
    errorMessage = null;
    _notify();

    try {
      await _authRepository.logout();
      _becomeSignedOut();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearTokenAndBecomeSignedOut();
        return status == AuthStatus.signedOut;
      }

      isSigningOut = false;
      errorMessage =
          'We could not sign you out. Check your connection and retry.';
      _notify();
      return false;
    } on TokenStorageException {
      isSigningOut = false;
      _becomeStorageFailure();
      return false;
    }
  }

  void returnToSignIn() {
    _becomeSignedOut();
  }
}
