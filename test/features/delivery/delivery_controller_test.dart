import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_controller.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

void main() {
  test(
    'movement replaces the task with the server status and revision',
    () async {
      final repository = _FakeDeliveryRepository();
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_pickedUpTask];

      final moved = await controller.advanceStatus(_pickedUpTask);

      expect(moved, isTrue);
      expect(repository.movementStatus, 'in_transit');
      expect(controller.taskById(_pickedUpTask.id)?.rawStatus, 'in_transit');
      expect(controller.taskById(_pickedUpTask.id)?.revision, 5);
      expect(
        controller.actionStatus(_pickedUpTask),
        DeliveryActionStatus.moved,
      );
    },
  );

  test('proof stays pending and completion is not inferred', () async {
    final controller = DeliveryController(
      deliveryRepository: _FakeDeliveryRepository(),
    );
    controller.tasks = <PickupTask>[_outForDeliveryTask];

    final submitted = await controller.submitProof(
      _outForDeliveryTask,
      identifierType: 'qr',
      identifier: 'RECIPIENT-QR',
    );

    expect(submitted, isTrue);
    expect(controller.proofs[_outForDeliveryTask.id]?.proofId, 'proof-1');
    expect(
      controller.actionStatus(_outForDeliveryTask),
      DeliveryActionStatus.proofAwaitingValidation,
    );
    expect(controller.completions[_outForDeliveryTask.id], isNull);
  });

  test('completion timeout reuses the same idempotency key', () async {
    final repository = _FakeDeliveryRepository()..failCompletionOnce = true;
    final controller = DeliveryController(deliveryRepository: repository);

    final first = await controller.submitCompletion(
      _outForDeliveryTask,
      evidenceId: 'proof-1',
    );
    final retry = await controller.retryCompletion(_outForDeliveryTask);

    expect(first, isFalse);
    expect(retry, isTrue);
    expect(repository.completionIdempotencyKeys.length, 2);
    expect(
      repository.completionIdempotencyKeys.first,
      repository.completionIdempotencyKeys.last,
    );
    expect(
      controller.actionStatus(_outForDeliveryTask),
      DeliveryActionStatus.completionAwaitingValidation,
    );
    expect(
      controller.completions[_outForDeliveryTask.id]?.isDelivered,
      isFalse,
    );
  });

  test('401 is delegated to the auth boundary', () async {
    ApiException? authFailure;
    final controller = DeliveryController(
      deliveryRepository: _FakeDeliveryRepository()
        ..loadError = const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'expired',
        ),
      onAuthFailure: (error) async => authFailure = error,
    );

    await controller.load();

    expect(controller.loadStatus, DeliveryLoadStatus.unauthorized);
    expect(authFailure?.statusCode, 401);
  });
}

class _FakeDeliveryRepository implements DeliveryRepository {
  Object? loadError;
  bool failCompletionOnce = false;
  String? movementStatus;
  final List<String> completionIdempotencyKeys = <String>[];

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    if (loadError != null) {
      throw loadError!;
    }
    return <PickupTask>[_outForDeliveryTask];
  }

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    return const DeliveryContext(
      taskId: 'delivery-task-1',
      status: 'delivery_accepted',
    );
  }

  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
  }) async {
    movementStatus = status;
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
    );
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
  }) async {
    completionIdempotencyKeys.add(idempotencyKey);
    if (failCompletionOnce) {
      failCompletionOnce = false;
      throw const ApiException.network(
        'timed out',
        networkFailure: ApiNetworkFailure.timeout,
      );
    }
    return const CompletionProjection(
      taskId: 'delivery-task-1',
      taskStatus: 'out_for_delivery',
      completionStatus: 'awaiting_validation',
      evidenceStatus: 'awaiting_validation',
      evidenceId: 'proof-1',
    );
  }
}

const _pickedUpTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'picked_up_from_hub',
  revision: 4,
);

const _outForDeliveryTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'out_for_delivery',
  revision: 7,
);
