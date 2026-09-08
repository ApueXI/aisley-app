import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

enum AuthStatus {
  checkingSession,
  signedOut,
  authenticating,
  authenticated,
  pendingApproval,
  rejected,
  suspendedOrDeactivated,
  invalidAffiliation,
  recoverableNetworkFailure,
  secureStorageFailure,
}

enum DashboardLoadStatus { idle, loading, loaded, failed }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required DashboardRepository dashboardRepository,
  }) : _authRepository = authRepository,
       _dashboardRepository = dashboardRepository;

  final AuthRepository _authRepository;
  final DashboardRepository _dashboardRepository;

  AuthStatus status = AuthStatus.checkingSession;
  DashboardLoadStatus dashboardStatus = DashboardLoadStatus.idle;
  CourierIdentity? courier;
  DashboardSnapshot? dashboard;
  String? errorMessage;
  String? dashboardErrorMessage;
  Duration? retryAfter;
  bool isSigningOut = false;

  Future<void> initialize() async {
    status = AuthStatus.checkingSession;
    errorMessage = null;
    retryAfter = null;
    notifyListeners();

    try {
      if (!await _authRepository.hasStoredToken()) {
        _becomeSignedOut();
        return;
      }

      courier = await _authRepository.currentCourier();
      status = AuthStatus.authenticated;
      notifyListeners();
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

  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) {
    return _authRepository.fetchLogisticsOptions(search: search);
  }

  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) {
    return _authRepository.register(request, onCancel: onCancel);
  }

  Future<void> signIn({required String email, required String password}) async {
    if (status == AuthStatus.authenticating) {
      return;
    }

    status = AuthStatus.authenticating;
    errorMessage = null;
    retryAfter = null;
    courier = null;
    dashboard = null;
    dashboardStatus = DashboardLoadStatus.idle;
    dashboardErrorMessage = null;
    notifyListeners();

    try {
      courier = await _authRepository.login(
        email: email,
        password: password,
        deviceName: _deviceName,
      );
      status = AuthStatus.authenticated;
      notifyListeners();
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

  Future<void> loadDashboard() async {
    if (status != AuthStatus.authenticated ||
        dashboardStatus == DashboardLoadStatus.loading) {
      return;
    }

    dashboardStatus = DashboardLoadStatus.loading;
    dashboardErrorMessage = null;
    notifyListeners();

    try {
      dashboard = await _dashboardRepository.fetchDashboard();
      dashboardStatus = DashboardLoadStatus.loaded;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _handleAuthError(error, fromSession: true);
        return;
      }

      dashboardStatus = DashboardLoadStatus.failed;
      dashboardErrorMessage = _messageForDashboardError(error);
      notifyListeners();
    } on TokenStorageException {
      _becomeStorageFailure();
    } on ApiContractException {
      dashboardStatus = DashboardLoadStatus.failed;
      dashboardErrorMessage =
          'The dashboard returned an unexpected response. Please retry.';
      notifyListeners();
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

  Future<bool> signOut() async {
    if (isSigningOut) {
      return false;
    }

    isSigningOut = true;
    errorMessage = null;
    notifyListeners();

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
      notifyListeners();
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

  static const _deviceName = 'Courier Flutter';

  Future<void> _handleAuthError(
    ApiException error, {
    bool fromSession = false,
  }) async {
    if (error.statusCode == 401) {
      await _clearTokenAndBecomeSignedOut(
        message: fromSession ? null : 'Your session is no longer valid.',
      );
      return;
    }

    if (error.statusCode == 403) {
      await _clearTokenAndSetBlocked(error);
      return;
    }

    if (fromSession && error.isNetworkError) {
      status = AuthStatus.recoverableNetworkFailure;
      errorMessage = _messageForAuthError(error);
      retryAfter = null;
      isSigningOut = false;
      notifyListeners();
      return;
    }

    status = AuthStatus.signedOut;
    errorMessage = _messageForAuthError(error);
    retryAfter = error.retryAfter;
    isSigningOut = false;
    notifyListeners();
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
    try {
      await _authRepository.clearStoredToken();
      final blockedStatus = _blockedStatusFor(error.code);
      status = blockedStatus;
      courier = null;
      dashboard = null;
      dashboardStatus = DashboardLoadStatus.idle;
      errorMessage = _messageForAuthError(error);
      isSigningOut = false;
      notifyListeners();
    } on TokenStorageException {
      _becomeStorageFailure();
    }
  }

  void _becomeSignedOut({String? message}) {
    status = AuthStatus.signedOut;
    courier = null;
    dashboard = null;
    dashboardStatus = DashboardLoadStatus.idle;
    dashboardErrorMessage = null;
    errorMessage = message;
    retryAfter = null;
    isSigningOut = false;
    notifyListeners();
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
    notifyListeners();
  }

  void _becomeStorageSafeFailure(String message) {
    status = AuthStatus.secureStorageFailure;
    courier = null;
    dashboard = null;
    errorMessage = message;
    isSigningOut = false;
    notifyListeners();
  }

  AuthStatus _blockedStatusFor(String code) {
    return switch (code) {
      'ACCOUNT_PENDING_APPROVAL' => AuthStatus.pendingApproval,
      'ACCOUNT_REJECTED' => AuthStatus.rejected,
      'ACCOUNT_SUSPENDED' ||
      'ACCOUNT_INACTIVE' => AuthStatus.suspendedOrDeactivated,
      'LOGISTICS_ASSOCIATION_INVALID' => AuthStatus.invalidAffiliation,
      _ => AuthStatus.invalidAffiliation,
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
      'THROTTLED' => 'Too many attempts. Please wait and try again.',
      _ when error.isNetworkError =>
        'Could not reach the service. Check your connection and retry.',
      _ => 'We could not complete sign-in. Please try again.',
    };
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
