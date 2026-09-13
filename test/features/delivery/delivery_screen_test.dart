import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

void main() {
  testWidgets(
    'shows Submit completion after proof 202 while proof awaits validation',
    (tester) async {
      final controller = DeliveryController(
        deliveryRepository: _WidgetDeliveryRepository(),
      )..tasks = <PickupTask>[_outForDeliveryTask];
      final proofSubmitted = await controller.submitProof(
        _outForDeliveryTask,
        identifierType: 'qr',
        identifier: 'RAW-QR-PAYLOAD',
      );

      expect(proofSubmitted, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: _authenticatedAuthController(),
            deliveryController: controller,
            task: _outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ORD-100'), findsOneWidget);
      expect(find.text('WB-100'), findsOneWidget);
      expect(
        find.text(
          'Proof is awaiting Logistics validation. Submit completion intent so Logistics can continue validation.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Submit completion'));
      expect(find.text('Submit completion'), findsOneWidget);
      expect(find.text('Delivery completed by the server.'), findsNothing);
    },
  );
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

class _WidgetDeliveryRepository implements DeliveryRepository {
  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    return <PickupTask>[_outForDeliveryTask];
  }

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    return const DeliveryContext(
      taskId: 'delivery-task-1',
      status: 'out_for_delivery',
      revision: 7,
      hub: PickupLocation(name: 'Makati Hub'),
      destination: PickupLocation(
        cityMunicipality: 'Pasig',
        province: 'Metro Manila',
      ),
    );
  }

  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
  }) async {
    return DeliveryStatusUpdate(
      taskId: taskId,
      status: status,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    return const ProofSubmission(
      taskId: 'delivery-task-1',
      proofId: 'proof-1',
      evidenceStatus: 'awaiting_validation',
      custodyState: 'out_for_delivery',
      completionEligible: false,
    );
  }

  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async {
    return const CompletionProjection(
      taskId: 'delivery-task-1',
      taskStatus: 'out_for_delivery',
      completionStatus: 'awaiting_validation',
      evidenceStatus: 'awaiting_validation',
      evidenceId: 'proof-1',
      revision: 7,
    );
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
  }) async {
    return const CompletionProjection(
      taskId: 'delivery-task-1',
      intentId: 'intent-1',
      taskStatus: 'out_for_delivery',
      completionStatus: 'awaiting_validation',
      evidenceStatus: 'awaiting_validation',
      evidenceId: 'proof-1',
      revision: 7,
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

const _outForDeliveryTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'out_for_delivery',
  revision: 7,
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  destinationArea: PickupLocation(
    cityMunicipality: 'Pasig',
    province: 'Metro Manila',
  ),
);
