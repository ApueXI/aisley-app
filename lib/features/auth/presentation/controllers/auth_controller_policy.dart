part of 'auth_controller.dart';

extension AuthControllerPolicy on AuthController {
  Future<void> handlePolicyAuthFailure(ApiException error) {
    return _handleAuthError(error, fromSession: true);
  }

  Future<void> completePolicyConsent() async {
    if (status != AuthStatus.policyConsentRequired) {
      return;
    }

    try {
      courier ??= await _authRepository.currentCourier();
      if (status != AuthStatus.policyConsentRequired) {
        return;
      }
      status = AuthStatus.authenticated;
      dashboard = null;
      dashboardStatus = DashboardLoadStatus.idle;
      dashboardErrorMessage = null;
      errorMessage = null;
      retryAfter = null;
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
}
