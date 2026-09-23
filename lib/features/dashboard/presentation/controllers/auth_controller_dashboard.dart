part of '../../../auth/presentation/controllers/auth_controller.dart';

extension AuthControllerDashboard on AuthController {
  Future<void> loadDashboard() async {
    if (status != AuthStatus.authenticated ||
        isSigningOut ||
        !canRetryDashboard) {
      return;
    }

    final requestEpoch = ++_dashboardRequestEpoch;
    dashboardStatus = DashboardLoadStatus.loading;
    dashboardErrorMessage = null;
    _notify();

    try {
      final snapshot = await _dashboardRepository.fetchDashboard();
      if (requestEpoch != _dashboardRequestEpoch ||
          status != AuthStatus.authenticated ||
          isSigningOut) {
        return;
      }
      dashboard = snapshot;
      dashboardStatus = DashboardLoadStatus.loaded;
      _notify();
    } on ApiException catch (error) {
      if (requestEpoch != _dashboardRequestEpoch ||
          status != AuthStatus.authenticated ||
          isSigningOut) {
        return;
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _handleAuthError(error, fromSession: true);
        return;
      }

      dashboardStatus = DashboardLoadStatus.failed;
      dashboardErrorMessage = _messageForDashboardError(error);
      if (error.statusCode == 429) {
        final delay = error.retryAfter ?? const Duration(seconds: 1);
        dashboardRetryAfter = delay;
        _dashboardRetryTimer = Timer(delay, () {
          _dashboardRetryTimer = null;
          dashboardRetryAfter = null;
          _notify();
        });
      }
      _notify();
    } on TokenStorageException {
      if (requestEpoch != _dashboardRequestEpoch) return;
      _becomeStorageFailure();
    } on ApiContractException {
      if (requestEpoch != _dashboardRequestEpoch ||
          status != AuthStatus.authenticated ||
          isSigningOut) {
        return;
      }
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
    if (error.statusCode == 429) {
      final seconds =
          (error.retryAfter ?? const Duration(seconds: 1)).inSeconds;
      return 'Too many dashboard requests. Try again after $seconds seconds.';
    }
    return switch (error.code) {
      'NOT_FOUND' => 'The dashboard service is not available yet.',
      _ when error.isNetworkError =>
        'Could not refresh the dashboard. Check your connection and retry.',
      _ => 'The dashboard could not be loaded. Please retry.',
    };
  }
}
