import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../../account/domain/account_models.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../dashboard/domain/dashboard_models.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';

part 'auth_controller_registration.dart';
part 'auth_controller_policy.dart';
part '../../../dashboard/presentation/controllers/auth_controller_dashboard.dart';
part 'auth_controller_session.dart';
part 'auth_controller_state.dart';

enum AuthStatus {
  checkingSession,
  signedOut,
  authenticating,
  authenticated,
  pendingApproval,
  rejected,
  suspendedOrDeactivated,
  invalidAffiliation,
  accessDenied,
  policyConsentRequired,
  recoverableNetworkFailure,
  secureStorageFailure,
}

enum DashboardLoadStatus { idle, loading, loaded, failed }

class AuthController extends ChangeNotifier {
  AuthController({
    required this._authRepository,
    required this._dashboardRepository,
    this._onSessionEnded,
  });

  final AuthRepository _authRepository;
  final DashboardRepository _dashboardRepository;
  final void Function()? _onSessionEnded;

  AuthStatus status = AuthStatus.checkingSession;
  DashboardLoadStatus dashboardStatus = DashboardLoadStatus.idle;
  CourierIdentity? courier;
  DashboardSnapshot? dashboard;
  String? errorMessage;
  String? dashboardErrorMessage;
  Duration? retryAfter;
  bool isSigningOut = false;

  static const _deviceName = 'Courier Flutter';

  void _notify() {
    notifyListeners();
  }
}
