part of '../../../auth/presentation/controllers/auth_controller.dart';

extension AuthControllerDashboard on AuthController {
  Future<void> loadDashboard() async {
    if (status != AuthStatus.authenticated ||
        dashboardStatus == DashboardLoadStatus.loading) {
      return;
    }

    dashboardStatus = DashboardLoadStatus.loading;
    dashboardErrorMessage = null;
    _notify();

    try {
      dashboard = await _dashboardRepository.fetchDashboard();
      dashboardStatus = DashboardLoadStatus.loaded;
      _notify();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _handleAuthError(error, fromSession: true);
        return;
      }

      dashboardStatus = DashboardLoadStatus.failed;
      dashboardErrorMessage = _messageForDashboardError(error);
      _notify();
    } on TokenStorageException {
      _becomeStorageFailure();
    } on ApiContractException {
      dashboardStatus = DashboardLoadStatus.failed;
      dashboardErrorMessage =
          'The dashboard returned an unexpected response. Please retry.';
      _notify();
    }
  }

  Future<void> retry() {
    if (status == AuthStatus.recoverableNetworkFailure ||
        status == AuthStatus.checkingSession ||
        status == AuthStatus.secureStorageFailure) {
      return initialize();
    }
    if (status == AuthStatus.authenticated) {
      return loadDashboard();
    }
    return Future<void>.value();
  }

  String _messageForDashboardError(ApiException error) {
    return switch (error.code) {
      'NOT_FOUND' => 'The dashboard service is not available yet.',
      _ when error.isNetworkError =>
        'Could not refresh the dashboard. Check your connection and retry.',
      _ => 'The dashboard could not be loaded. Please retry.',
    };
  }
}
