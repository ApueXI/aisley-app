import 'dart:async';

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

    test('ignores a dashboard response that arrives after sign-out', () async {
      final pending = Completer<DashboardSnapshot>();
      final dashboardRepository = FakeDashboardRepository()..pending = pending;
      final controller = AuthController(
        authRepository: FakeAuthRepository(),
        dashboardRepository: dashboardRepository,
      );
      await controller.signIn(email: 'courier@example.com', password: 'secret');

      final load = controller.loadDashboard();
      expect(controller.dashboardStatus, DashboardLoadStatus.loading);
      await controller.signOut();
      pending.complete(DashboardSnapshot.fromJson(_dashboardJson));
      await load;

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.dashboard, isNull);
      expect(controller.dashboardStatus, DashboardLoadStatus.idle);
    });

    test('ignores an older dashboard response after a newer refresh', () async {
      final first = Completer<DashboardSnapshot>();
      final second = Completer<DashboardSnapshot>();
      final dashboardRepository = FakeDashboardRepository()
        ..responses.addAll([first, second]);
      final controller = AuthController(
        authRepository: FakeAuthRepository(),
        dashboardRepository: dashboardRepository,
      );
      await controller.signIn(email: 'courier@example.com', password: 'secret');

      final olderLoad = controller.loadDashboard();
      final newerLoad = controller.loadDashboard();
      final current = DashboardSnapshot.fromJson(_dashboardJson);
      second.complete(current);
      await newerLoad;
      first.complete(DashboardSnapshot.fromJson(const <String, dynamic>{}));
      await olderLoad;

      expect(controller.dashboard, same(current));
      expect(controller.dashboardStatus, DashboardLoadStatus.loaded);
    });

    test('keeps the last scaffold visibly stale on an offline refresh', () async {
      final dashboardRepository = FakeDashboardRepository();
      final controller = AuthController(
        authRepository: FakeAuthRepository(),
        dashboardRepository: dashboardRepository,
      );
      await controller.signIn(email: 'courier@example.com', password: 'secret');
      await controller.loadDashboard();
      final earlier = controller.dashboard;
      dashboardRepository.error = const ApiException.network('private detail');

      await controller.loadDashboard();

      expect(controller.dashboard, same(earlier));
      expect(controller.dashboardStatus, DashboardLoadStatus.failed);
      expect(controller.dashboardErrorMessage, isNot(contains('private')));
    });

    test('honors dashboard retry-after and does not retry early', () async {
      final dashboardRepository = FakeDashboardRepository()
        ..error = const ApiException(
          statusCode: 429,
          code: 'THROTTLED',
          message: 'private server message',
          retryAfter: Duration(milliseconds: 50),
        );
      final controller = AuthController(
        authRepository: FakeAuthRepository(),
        dashboardRepository: dashboardRepository,
      );
      await controller.signIn(email: 'courier@example.com', password: 'secret');

      await controller.loadDashboard();
      expect(controller.dashboardStatus, DashboardLoadStatus.failed);
      expect(controller.canRetryDashboard, isFalse);
      expect(controller.dashboardErrorMessage, isNot(contains('private')));
      await controller.loadDashboard();
      expect(dashboardRepository.fetchCount, 1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.canRetryDashboard, isTrue);
      controller.dispose();
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
  Completer<DashboardSnapshot>? pending;
  final List<Completer<DashboardSnapshot>> responses = [];
  int fetchCount = 0;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    fetchCount++;
    if (responses.isNotEmpty) return responses.removeAt(0).future;
    if (pending case final pending?) return pending.future;
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
