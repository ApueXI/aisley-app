import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';
import 'package:aisley_app/features/policy/presentation/policy_controller.dart';

void main() {
  testWidgets('Courier can open the registration form from sign in', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    );
    await controller.initialize();

    await tester.pumpWidget(CourierApp(authController: controller));
    await tester.tap(find.text('New Courier? Register here'));
    await tester.pumpAndSettle();

    expect(find.text('Create your Courier account'), findsOneWidget);
    expect(find.text('Logistics organization'), findsOneWidget);
    expect(find.text('Required evidence'), findsOneWidget);
    expect(find.textContaining('No map pin is required'), findsOneWidget);
  });

  testWidgets('Courier can sign in and reach the dashboard skeleton', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    );
    await controller.initialize();

    await tester.pumpWidget(CourierApp(authController: controller));
    expect(find.text('Courier sign in'), findsOneWidget);

    await tester.enterText(
      find.bySemanticsLabel('Email'),
      'courier@example.com',
    );
    await tester.enterText(find.bySemanticsLabel('Password'), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Courier dashboard'), findsOneWidget);
    expect(find.text('Available work'), findsOneWidget);
    expect(find.text('Unavailable in this build'), findsNWidgets(3));
    expect(
      find.text(
        'Operational delivery data will appear here when it is available.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('policy-gated dashboard opens consent without signing out', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.policyConsentRequired;
    final policyController = PolicyController(policyApi: _FakePolicyApi());

    await tester.pumpWidget(
      CourierApp(
        authController: authController,
        policyController: policyController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Policy & consent'), findsOneWidget);
    expect(find.text('Platform policies'), findsOneWidget);
    expect(
      find.text(
        'Accept every required current policy before Courier dashboard access is restored.',
      ),
      findsOneWidget,
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  final CourierIdentity courier = CourierIdentity.fromJson(
    const <String, dynamic>{
      'id': 'courier-1',
      'email': 'courier@example.com',
      'role': 'courier',
      'status': 'active',
      'profile': <String, dynamic>{'first_name': 'Maya', 'last_name': 'Santos'},
      'logistics': <String, dynamic>{
        'status': 'approved',
        'organization': 'Aisley Express',
        'hub': 'Makati Hub',
      },
    },
  );

  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    return const <LogisticsOption>[
      LogisticsOption(id: 'logistics-1', businessName: 'Aisley Express'),
    ];
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
    return courier;
  }

  @override
  Future<CourierIdentity> currentCourier() async => courier;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    return DashboardSnapshot.fromJson(const <String, dynamic>{
      'data': <dynamic>[],
      'meta': <String, dynamic>{'generated_at': 'now'},
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
    });
  }
}

class _FakePolicyApi implements PolicyApi {
  @override
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    return _policyDocument(type);
  }

  @override
  Future<PolicyHistory> fetchHistory(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    return PolicyHistory(
      type: type,
      label: type.fallbackLabel,
      versions: const <PolicyHistoryEntry>[],
    );
  }

  @override
  Future<PolicyDocument> fetchHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  }) async {
    return _policyDocument(type);
  }

  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async {
    return const PolicyConsentStatus(
      policies: <PolicyConsentItem>[
        PolicyConsentItem(
          rawType: 'terms_of_service',
          label: 'Terms of Service',
          required: true,
          accepted: false,
          acceptedAt: null,
          currentVersion: 1,
          acceptedVersion: null,
        ),
        PolicyConsentItem(
          rawType: 'privacy_policy',
          label: 'Privacy Policy',
          required: true,
          accepted: false,
          acceptedAt: null,
          currentVersion: 1,
          acceptedVersion: null,
        ),
      ],
      allRequiredAccepted: false,
    );
  }

  @override
  Future<PolicyAcceptance> accept({
    required PolicyType type,
    required int version,
  }) async {
    return PolicyAcceptance(
      type: type,
      label: type.fallbackLabel,
      version: _policyDocument(type).version,
      acceptedAt: DateTime.utc(2026, 9, 12),
    );
  }

  @override
  void clearPublicCache() {}
}

PolicyDocument _policyDocument(PolicyType type) {
  return PolicyDocument(
    type: type,
    label: type.fallbackLabel,
    version: PolicyVersion(
      id: '${type.apiValue}-1',
      version: 1,
      title: type.fallbackLabel,
      content: 'Policy content.',
      status: 'published',
      changeSummary: null,
      requiresReconsent: false,
      publishedAt: DateTime.utc(2026, 9, 12),
    ),
  );
}
