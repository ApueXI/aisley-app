import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/account/data/account_repository.dart';
import 'package:aisley_app/features/account/domain/account_models.dart';
import 'package:aisley_app/features/account/presentation/controllers/account_controller.dart';
import 'package:aisley_app/features/account/presentation/account_screen.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  testWidgets('renders the server-backed account form and read-only details', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      authRepository: _FakeAuthRepository(),
      dashboardRepository: _FakeDashboardRepository(),
    )..status = AuthStatus.authenticated;
    final accountController = AccountController(
      accountRepository: _FakeAccountRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          authController: authController,
          accountController: accountController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal information'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Aisley Express'), findsOneWidget);
    expect(find.text('Main Hub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });
}

class _FakeAccountRepository implements AccountRepository {
  @override
  Future<CourierAccount> fetchAccount() async {
    return CourierAccount.fromJson(_accountJson);
  }

  @override
  Future<CourierAccount> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    String? idempotencyKey,
  }) async {
    return CourierAccount.fromJson(_accountJson);
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
    return CourierAccount.fromJson(_accountJson);
  }

  @override
  Future<ProfilePhotoData> fetchProfilePhoto(String profilePhotoUrl) async {
    throw const ApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'missing',
    );
  }

  @override
  Future<void> deleteProfilePhoto() async {}
}

class _FakeAuthRepository implements AuthRepository {
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
  Future<CourierIdentity> currentCourier() async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    throw UnimplementedError();
  }
}

const _accountJson = <String, dynamic>{
  'id': 'courier-1',
  'email': 'courier@example.com',
  'role': 'courier',
  'status': 'active',
  'profile': <String, dynamic>{
    'first_name': 'Ana',
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
    'hub_name': 'Main Hub',
  },
  'security': <String, dynamic>{
    'email_editable': false,
    'profile_photo_editable': true,
    'password_change_requires_current_password': true,
  },
};
