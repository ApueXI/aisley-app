import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';
import 'package:aisley_app/features/policy/presentation/policy_controller.dart';
import 'package:aisley_app/features/policy/presentation/policy_screen.dart';

void main() {
  testWidgets(
    'shows safe policy text, explicit confirmation, and history entry',
    (tester) async {
      final policyController = PolicyController(policyApi: _WidgetPolicyApi());
      final authController = AuthController(
        authRepository: _WidgetAuthRepository(),
        dashboardRepository: _WidgetDashboardRepository(),
      )..status = AuthStatus.authenticated;

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyScreen(
            authController: authController,
            policyController: policyController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Platform policies'), findsOneWidget);
      expect(find.text('These are plain policy terms.'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'I have read and agree to the current Terms of Service, version 3.',
        ),
        findsOneWidget,
      );
      expect(find.text('View published history'), findsNWidgets(2));
    },
  );

  testWidgets('shows an actionable message when the policy route is missing', (
    tester,
  ) async {
    final policyController = PolicyController(
      policyApi: _WidgetPolicyApi(
        statusError: const ApiException(
          statusCode: 404,
          code: 'NOT_FOUND',
          message: 'not found',
        ),
      ),
    );
    final authController = AuthController(
      authRepository: _WidgetAuthRepository(),
      dashboardRepository: _WidgetDashboardRepository(),
    )..status = AuthStatus.authenticated;

    await tester.pumpWidget(
      MaterialApp(
        home: PolicyScreen(
          authController: authController,
          policyController: policyController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Policy information unavailable'), findsOneWidget);
    expect(
      find.text(
        'The policy consent endpoint is unavailable on this API. Deploy the policy routes and retry.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _WidgetPolicyApi implements PolicyApi {
  _WidgetPolicyApi({this.statusError});

  final Object? statusError;

  @override
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    return _document(type, type == PolicyType.termsOfService ? 3 : 2);
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
    return _document(type, version);
  }

  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async {
    if (statusError != null) {
      throw statusError!;
    }
    return const PolicyConsentStatus(
      policies: <PolicyConsentItem>[
        PolicyConsentItem(
          rawType: 'terms_of_service',
          label: 'Terms of Service',
          required: true,
          accepted: false,
          acceptedAt: null,
          currentVersion: 3,
          acceptedVersion: null,
        ),
        PolicyConsentItem(
          rawType: 'privacy_policy',
          label: 'Privacy Policy',
          required: true,
          accepted: true,
          acceptedAt: null,
          currentVersion: 2,
          acceptedVersion: 2,
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
      version: _document(type, version).version,
      acceptedAt: DateTime.utc(2026, 9, 10),
    );
  }

  @override
  void clearPublicCache() {}
}

class _WidgetAuthRepository implements AuthRepository {
  @override
  Future<bool> hasStoredToken() async => false;

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
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> currentCourier() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _WidgetDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    return DashboardSnapshot.fromJson(const <String, dynamic>{
      'data': <dynamic>[],
      'meta': <String, dynamic>{'generated_at': 'now'},
      'sections': <String, dynamic>{},
      'freshness': <String, dynamic>{'state': 'scaffold'},
    });
  }
}

PolicyDocument _document(PolicyType type, int version) {
  return PolicyDocument(
    type: type,
    label: type.fallbackLabel,
    version: PolicyVersion(
      id: '${type.apiValue}-$version',
      version: version,
      title: '${type.fallbackLabel} version $version',
      content: type == PolicyType.termsOfService
          ? 'These are plain policy terms.'
          : 'These are plain privacy terms.',
      status: 'published',
      changeSummary: null,
      requiresReconsent: true,
      publishedAt: DateTime.utc(2026, 9, 10),
    ),
  );
}
