import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

void main() {
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
