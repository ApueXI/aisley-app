import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/batch/data/final_mile_batch_repository.dart';
import 'package:aisley_app/features/batch/domain/final_mile_batch_models.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  testWidgets('reviews parcel context and accepts the batch with one action', (
    tester,
  ) async {
    final repository = _WidgetBatchRepository();
    final controller = FinalMileBatchController(repository: repository);
    await controller.load();
    final auth = _authController();

    await tester.pumpWidget(
      MaterialApp(
        home: FinalMileBatchDetailScreen(
          authController: auth,
          batchController: controller,
          scheduleId: 'schedule-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DSP-100'), findsOneWidget);
    expect(find.text('2 parcels'), findsOneWidget);
    expect(find.text('Parcel price: PHP 1250.00'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.textContaining('not cash due on delivery'), findsWidgets);
    expect(find.text('Accept hub delivery'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Accept entire batch'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Accept entire batch'));
    await tester.pumpAndSettle();
    expect(find.text('Accept this entire batch?'), findsOneWidget);
    expect(
      find.textContaining('accept responsibility for all 2 parcels'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Accept entire batch'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(find.text('Entire batch accepted'), findsOneWidget);
    expect(find.textContaining('does not record hub pickup'), findsOneWidget);
  });
}

class _WidgetBatchRepository implements FinalMileBatchRepository {
  var accepted = false;
  var acceptCalls = 0;

  @override
  Future<List<FinalMileBatch>> fetchBatches() async => <FinalMileBatch>[
    _batch(
      accepted ? FinalMileBatchStatus.accepted : FinalMileBatchStatus.offered,
    ),
  ];

  @override
  Future<FinalMileBatch> fetchBatch(String scheduleId) async => _batch(
    accepted ? FinalMileBatchStatus.accepted : FinalMileBatchStatus.offered,
  );

  @override
  Future<FinalMileBatch> acceptBatch(String scheduleId) async {
    acceptCalls++;
    accepted = true;
    return _batch(FinalMileBatchStatus.accepted);
  }
}

FinalMileBatch _batch(FinalMileBatchStatus status) {
  return FinalMileBatch(
    id: 'schedule-1',
    reference: 'DSP-100',
    scheduledFor: DateTime.utc(2026, 9, 27, 1, 30),
    parcelCount: 2,
    status: status,
    tasks: const <FinalMileBatchTask>[
      FinalMileBatchTask(
        id: 'task-1',
        status: 'delivery_assigned',
        orderReference: 'ORD-100',
        parcel: FinalMileBatchParcel(
          itemCount: 3,
          price: '1250.00',
          currency: 'PHP',
        ),
        destination: FinalMileBatchDestination(
          cityMunicipality: 'Makati City',
          province: 'Metro Manila',
        ),
      ),
      FinalMileBatchTask(
        id: 'task-2',
        status: 'delivery_assigned',
        orderReference: 'ORD-101',
        parcel: FinalMileBatchParcel(
          itemCount: 1,
          price: '499.50',
          currency: 'PHP',
        ),
        destination: FinalMileBatchDestination(
          cityMunicipality: 'Pasig City',
          province: 'Metro Manila',
        ),
      ),
    ],
  );
}

AuthController _authController() {
  return AuthController(
    authRepository: _WidgetAuthRepository(),
    dashboardRepository: _WidgetDashboardRepository(),
  );
}

class _WidgetAuthRepository implements AuthRepository {
  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async =>
      const <LogisticsOption>[];

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async => throw UnimplementedError();

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async => throw UnimplementedError();

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
