import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  group('AuthController', () {
    test('signs in and loads the protected dashboard scaffold', () async {
      final authRepository = FakeAuthRepository();
      final dashboardRepository = FakeDashboardRepository();
      final controller = AuthController(
        authRepository: authRepository,
        dashboardRepository: dashboardRepository,
      );

      await controller.signIn(email: 'COURIER@example.com', password: 'secret');
      expect(controller.status, AuthStatus.authenticated);
      expect(authRepository.lastEmail, 'COURIER@example.com');

      await controller.loadDashboard();
      expect(controller.dashboardStatus, DashboardLoadStatus.loaded);
      expect(
        controller.dashboard?.freshness.state,
        DashboardFreshnessState.scaffold,
      );
    });

    test('maps pending approval to an explicit blocked state', () async {
      final authRepository = FakeAuthRepository()
        ..loginError = const ApiException(
          statusCode: 403,
          code: 'ACCOUNT_PENDING_APPROVAL',
          message: 'private server message',
        );
      final controller = AuthController(
        authRepository: authRepository,
        dashboardRepository: FakeDashboardRepository(),
      );

      await controller.signIn(email: 'courier@example.com', password: 'secret');

      expect(controller.status, AuthStatus.pendingApproval);
      expect(
        controller.errorMessage,
        'Your Courier application is awaiting Logistics approval.',
      );
      expect(authRepository.tokenCleared, isTrue);
    });

    test('preserves the session and routes policy denial to consent', () async {
      final authRepository = FakeAuthRepository();
      final dashboardRepository = FakeDashboardRepository()
        ..error = const ApiException(
          statusCode: 403,
          code: 'POLICY_CONSENT_REQUIRED',
          message: 'consent required',
        );
      final controller = AuthController(
        authRepository: authRepository,
        dashboardRepository: dashboardRepository,
      );

      await controller.signIn(email: 'courier@example.com', password: 'secret');
      await controller.loadDashboard();

      expect(controller.status, AuthStatus.policyConsentRequired);
      expect(controller.courier, isNotNull);
      expect(controller.dashboard, isNull);
      expect(authRepository.tokenCleared, isFalse);
      expect(
        controller.errorMessage,
        'Review and accept the current Terms of Service and Privacy Policy to continue.',
      );
    });

    test(
      'does not label an unrecognized 403 as an affiliation failure',
      () async {
        final authRepository = FakeAuthRepository()
          ..loginError = const ApiException(
            statusCode: 403,
            code: 'FORBIDDEN_ROLE',
            message: 'private server message',
          );
        final controller = AuthController(
          authRepository: authRepository,
          dashboardRepository: FakeDashboardRepository(),
        );

        await controller.signIn(
          email: 'courier@example.com',
          password: 'secret',
        );

        expect(controller.status, AuthStatus.accessDenied);
        expect(authRepository.tokenCleared, isTrue);
      },
    );

    test('preserves a session on a recoverable restore failure', () async {
      final authRepository = FakeAuthRepository()
        ..hasToken = true
        ..currentCourierError = const ApiException.network('private detail');
      final controller = AuthController(
        authRepository: authRepository,
        dashboardRepository: FakeDashboardRepository(),
      );

      await controller.initialize();

      expect(controller.status, AuthStatus.recoverableNetworkFailure);
      expect(authRepository.tokenCleared, isFalse);
    });

    test('shows a safe failure when secure storage cannot be read', () async {
      final authRepository = FakeAuthRepository()
        ..storedTokenError = TokenStorageException(
          'read',
          StateError('secret service unavailable'),
        );
      final controller = AuthController(
        authRepository: authRepository,
        dashboardRepository: FakeDashboardRepository(),
      );

      await controller.initialize();

      expect(controller.status, AuthStatus.secureStorageFailure);
      expect(controller.courier, isNull);
    });
  });
}

class FakeAuthRepository implements AuthRepository {
  final courier = _courier();
  bool hasToken = false;
  bool tokenCleared = false;
  String? lastEmail;
  Object? loginError;
  Object? currentCourierError;
  Object? storedTokenError;

  @override
  Future<bool> hasStoredToken() async {
    final error = storedTokenError;
    if (error != null) {
      throw error;
    }
    return hasToken;
  }

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    return const <LogisticsOption>[];
  }

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    lastEmail = email;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    hasToken = true;
    return courier;
  }

  @override
  Future<CourierIdentity> currentCourier() async {
    final error = currentCourierError;
    if (error != null) {
      throw error;
    }
    return courier;
  }

  @override
  Future<void> logout() async {
    tokenCleared = true;
    hasToken = false;
  }

  @override
  Future<void> clearStoredToken() async {
    tokenCleared = true;
    hasToken = false;
  }
}

class FakeDashboardRepository implements DashboardRepository {
  Object? error;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    final fetchError = error;
    if (fetchError != null) {
      throw fetchError;
    }
    return DashboardSnapshot.fromJson(_dashboardJson);
  }
}

CourierIdentity _courier() {
  return CourierIdentity.fromJson(const <String, dynamic>{
    'id': 'courier-1',
    'email': 'courier@example.com',
    'role': 'courier',
    'status': 'active',
    'profile': <String, dynamic>{
      'first_name': 'Maya',
      'last_name': 'Santos',
      'age': 28,
    },
    'logistics': <String, dynamic>{
      'status': 'approved',
      'organization': 'Aisley Express',
      'hub': 'Makati Hub',
    },
  });
}

const _dashboardJson = <String, dynamic>{
  'data': <dynamic>[],
  'meta': <String, dynamic>{'next_cursor': null, 'generated_at': 'now'},
  'sections': <String, dynamic>{
    'notifications': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
    'available_tasks': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
    'active_tasks': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
  },
  'freshness': <String, dynamic>{
    'state': 'scaffold',
    'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    'generated_at': 'now',
  },
};
