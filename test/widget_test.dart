import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/features/account/data/account_repository.dart';
import 'package:aisley_app/features/account/domain/account_models.dart';
import 'package:aisley_app/features/account/presentation/controllers/account_controller.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
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
    await _pumpUntilFound(tester, find.text('Logistics organization'));

    expect(find.text('Create your Courier account'), findsOneWidget);
    expect(find.text('Logistics organization'), findsOneWidget);
    expect(find.text('Required evidence'), findsOneWidget);
    expect(find.textContaining('No map pin is required'), findsOneWidget);
  });

  testWidgets('registration explains local validation failures at the top', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    );
    await controller.initialize();

    await tester.pumpWidget(CourierApp(authController: controller));
    await tester.tap(find.text('New Courier? Register here'));
    await _pumpUntilFound(tester, find.text('Logistics organization'));
    await tester.ensureVisible(find.text('Submit registration'));
    await tester.tap(find.text('Submit registration'));
    await tester.pump();

    expect(
      find.text(
        'Some required information is missing or invalid. Review the highlighted fields below before submitting.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enter your first name.'), findsOneWidget);
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

  testWidgets('dashboard refreshes its avatar after a profile photo update', (
    WidgetTester tester,
  ) async {
    final authController =
        AuthController(
            authRepository: _FakeAuthRepository(),
            dashboardRepository: _FakeDashboardRepository(),
          )
          ..status = AuthStatus.authenticated
          ..courier = _FakeAuthRepository().courier;
    final accountController = AccountController(
      accountRepository: _FakeDashboardAccountRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authController: authController,
          accountController: accountController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dashboard-profile-photo')),
      findsNothing,
    );

    accountController.profilePhoto = ProfilePhotoData(
      bytes: Uint8List.fromList(_onePixelPng),
      contentType: 'image/png',
    );
    accountController.profilePhotoStatus = ProfilePhotoStatus.available;
    accountController.notifyListeners();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('dashboard-profile-photo')),
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var index = 0; index < 100; index++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
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

class _FakeDashboardAccountRepository implements AccountRepository {
  @override
  Future<CourierAccount> fetchAccount() async {
    return CourierAccount.fromJson(_dashboardAccountJson);
  }

  @override
  Future<CourierAccount> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    String? idempotencyKey,
  }) async {
    return CourierAccount.fromJson(_dashboardAccountJson);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {}

  @override
  Future<CourierAccount> uploadProfilePhoto({
    required ProfilePhotoSelection selection,
    String? idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    return CourierAccount.fromJson(_dashboardAccountJson);
  }

  @override
  Future<ProfilePhotoData> fetchProfilePhoto(String profilePhotoUrl) async {
    return ProfilePhotoData(
      bytes: Uint8List.fromList(_onePixelPng),
      contentType: 'image/png',
    );
  }

  @override
  Future<void> deleteProfilePhoto() async {}
}

const _dashboardAccountJson = <String, dynamic>{
  'id': 'courier-1',
  'email': 'courier@example.com',
  'role': 'courier',
  'status': 'active',
  'profile': <String, dynamic>{
    'first_name': 'Maya',
    'middle_name': null,
    'last_name': 'Santos',
    'contact_number': '09171234567',
    'sex': 'female',
    'birth_date': '1999-01-01',
    'age': 27,
    'profile_photo_url': null,
  },
  'affiliation': <String, dynamic>{
    'status': 'approved',
    'organization_name': 'Aisley Express',
    'hub_name': 'Makati Hub',
  },
  'security': <String, dynamic>{
    'email_editable': false,
    'profile_photo_editable': true,
    'password_change_requires_current_password': true,
  },
};

const _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

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
