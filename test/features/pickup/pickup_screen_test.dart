import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_controller.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';

void main() {
  testWidgets('accepts a first-mile task before showing pickup confirmation', (
    tester,
  ) async {
    final controller = PickupController(
      pickupRepository: _WidgetPickupRepository(),
    );
    final authController = _authenticatedAuthController();

    await tester.pumpWidget(
      MaterialApp(
        home: PickupScreen(
          authController: authController,
          pickupController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seller pickups'), findsOneWidget);
    expect(find.text('ORD-100'), findsOneWidget);
    await tester.ensureVisible(find.text('ORD-100'));
    await tester.tap(find.text('ORD-100'));
    await tester.pumpAndSettle();

    expect(find.text('Accept Seller pickup'), findsOneWidget);
    expect(find.text('Pickup details'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept Seller pickup'));
    await tester.pumpAndSettle();
    expect(find.text('Accept this task?'), findsOneWidget);
    await tester.tap(find.text('Accept task'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Verify Seller handoff'), findsOneWidget);
    expect(find.text('Confirm pickup'), findsOneWidget);
    expect(find.text('Pickup confirmed'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ORD-100');
    await tester.tap(find.text('Confirm pickup'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup confirmed'), findsOneWidget);
    expect(
      find.text('The server recorded physical pickup from the Seller.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Picked up from Seller'), findsOneWidget);
  });

  testWidgets('shows final-mile evidence as awaiting validation', (
    tester,
  ) async {
    final controller = PickupController(
      pickupRepository: _WidgetPickupRepository(includeFinalMile: true),
    );
    final authController = _authenticatedAuthController();

    await tester.pumpWidget(
      MaterialApp(
        home: PickupTaskDetailScreen(
          authController: authController,
          pickupController: controller,
          task: _finalMileTask,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ORD-100');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit hub pickup evidence'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Awaiting Logistics validation'),
      findsOneWidget,
    );
    expect(controller.lastFinalMilePickup?.custodyState, 'delivery_accepted');
    expect(
      controller.lastFinalMilePickup?.evidenceStatus,
      'awaiting_validation',
    );
    expect(find.text('Pickup confirmed'), findsNothing);
  });

  testWidgets('keeps an unavailable section distinct from an empty section', (
    tester,
  ) async {
    final controller = PickupController(
      pickupRepository: _WidgetPickupRepository()
        ..finalMileError = const ApiException(
          statusCode: 503,
          code: 'SERVER_ERROR',
          message: 'temporary service failure',
        ),
    );
    final authController = _authenticatedAuthController();

    await tester.pumpWidget(
      MaterialApp(
        home: PickupScreen(
          authController: authController,
          pickupController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORD-100'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The pickup service could not complete the request. Please retry.',
      ),
      findsOneWidget,
    );
    expect(find.text('No hub pickups are assigned right now.'), findsNothing);
  });
}

AuthController _authenticatedAuthController() {
  final controller = AuthController(
    authRepository: _WidgetAuthRepository(),
    dashboardRepository: _WidgetDashboardRepository(),
  );
  controller.status = AuthStatus.authenticated;
  controller.courier = CourierIdentity.fromJson(const <String, dynamic>{
    'id': 'courier-1',
    'email': 'courier@example.com',
    'role': 'courier',
    'status': 'active',
    'profile': <String, dynamic>{'first_name': 'Ana', 'last_name': 'Santos'},
    'logistics': <String, dynamic>{
      'status': 'approved',
      'organization': 'Aisley Express',
      'hub': 'Makati Hub',
    },
  });
  return controller;
}

class _WidgetPickupRepository implements PickupRepository {
  _WidgetPickupRepository({this.includeFinalMile = false});

  final bool includeFinalMile;
  Object? finalMileError;

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    return FirstMileTaskPage(tasks: <PickupTask>[_firstMileTask]);
  }

  @override
  Future<PickupTask> acceptFirstMileTask(String taskId) async {
    return _firstMileTask.copyWith(rawStatus: 'accepted');
  }

  @override
  Future<WaybillResolution> resolveWaybill(String payload) async {
    return const WaybillResolution(taskId: 'task-1');
  }

  @override
  Future<FirstMilePickupResult> confirmFirstMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required String idempotencyKey,
  }) async {
    return const FirstMilePickupResult(
      taskId: 'task-1',
      taskStatus: 'picked_up_from_seller',
      orderStatus: 'picked_up',
      nextStep: 'Transfer the parcel to the Logistics hub.',
    );
  }

  @override
  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId) async {
    return const PickupRouteManifest(status: RouteManifestStatus.pending);
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    final error = finalMileError;
    if (error != null) {
      throw error;
    }
    return includeFinalMile
        ? <PickupTask>[_finalMileTask]
        : const <PickupTask>[];
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async => _finalMileTask;

  @override
  Future<PickupTask> acceptFinalMileTask(String taskId) async => _finalMileTask;

  @override
  Future<FinalMileRejectionResult> rejectFinalMileTask({
    required String taskId,
    required String reason,
    required String idempotencyKey,
  }) async {
    return FinalMileRejectionResult(
      taskId: taskId,
      status: 'rejected',
      rejectionReason: reason,
      respondedAt: DateTime.utc(2026, 9, 13),
    );
  }

  @override
  Future<FinalMilePickupSubmission> submitFinalMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    return const FinalMilePickupSubmission(
      taskId: 'delivery-task-1',
      evidenceId: 'evidence-1',
      evidenceStatus: 'awaiting_validation',
      custodyState: 'delivery_accepted',
    );
  }
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
    return const DashboardSnapshot(
      sections: <String, DashboardSection>{},
      freshness: DashboardFreshness(state: DashboardFreshnessState.scaffold),
    );
  }
}

final _firstMileTask = PickupTask(
  id: 'task-1',
  leg: PickupTaskLeg.firstMile,
  rawStatus: 'assigned',
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  pickup: PickupLocation(
    name: 'Santos Shop',
    addressLine1: '10 Main Street',
    barangay: 'Poblacion',
    cityMunicipality: 'Makati',
    province: 'Metro Manila',
    region: 'NCR',
    postalCode: '1200',
  ),
  destinationArea: PickupLocation(
    cityMunicipality: 'Pasig',
    province: 'Metro Manila',
  ),
  pickupScheduleId: 'schedule-1',
  schedule: PickupSchedule(
    id: 'schedule-1',
    reference: 'SCH-100',
    startsAt: DateTime.utc(2026, 9, 12, 1),
    endsAt: DateTime.utc(2026, 9, 12, 3),
  ),
);

const _finalMileTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'delivery_accepted',
  revision: 4,
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  pickup: PickupLocation(name: 'Makati Hub'),
  destinationArea: PickupLocation(
    cityMunicipality: 'Pasig',
    province: 'Metro Manila',
  ),
);
