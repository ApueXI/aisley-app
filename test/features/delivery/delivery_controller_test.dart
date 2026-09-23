import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
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

  test('uncertain movement retries the same revision and UUID key', () async {
    final repository = _FakeDeliveryRepository()
      ..listedTask = _pickedUpTask
      ..failMovementOnce = true;
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_pickedUpTask];

    final first = await controller.advanceStatus(_pickedUpTask);
    final retry = await controller.retryMovement(_pickedUpTask);

    expect(first, isFalse);
    expect(retry, isTrue);
    expect(repository.movementIdempotencyKeys, hasLength(2));
    expect(
      repository.movementIdempotencyKeys.first,
      repository.movementIdempotencyKeys.last,
    );
    expect(controller.taskById(_pickedUpTask.id)?.rawStatus, 'in_transit');
  });

  test('proof stays pending and completion is not inferred', () async {
    final controller = DeliveryController(
      deliveryRepository: _FakeDeliveryRepository(),
    );
    controller.tasks = <PickupTask>[_outForDeliveryTask];

    final submitted = await controller.submitProof(
      _outForDeliveryTask,
      photo: _photo(),
    );

    expect(submitted, isTrue);
    expect(controller.proofs[_outForDeliveryTask.id]?.proofId, 'proof-1');
    expect(
      controller.actionStatus(_outForDeliveryTask),
      DeliveryActionStatus.proofAwaitingValidation,
    );
    expect(controller.completions[_outForDeliveryTask.id], isNull);
  });

  test(
    'photo proof uses the exact task revision, not a stale list revision',
    () async {
      final repository = _FakeDeliveryRepository()
        ..listedTask = _outForDeliveryTask.copyWith(revision: 8);
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask];

      final submitted = await controller.submitProof(
        _outForDeliveryTask,
        photo: _photo(),
      );

      expect(submitted, isTrue);
      expect(repository.proofExpectedRevisions, <int>[8]);
    },
  );

  test('wrong exact task identity blocks photo upload', () async {
    final repository = _FakeDeliveryRepository()
      ..listedTask = const PickupTask(
        id: 'different-task',
        leg: PickupTaskLeg.finalMile,
        rawStatus: 'out_for_delivery',
        revision: 7,
      );
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];

    final submitted = await controller.submitProof(
      _outForDeliveryTask,
      photo: _photo(),
    );

    expect(submitted, isFalse);
    expect(repository.proofExpectedRevisions, isEmpty);
    expect(
      controller.actionStatus(_outForDeliveryTask),
      DeliveryActionStatus.failed,
    );
  });

  test('server task no longer out for delivery blocks photo upload', () async {
    final repository = _FakeDeliveryRepository()
      ..listedTask = _outForDeliveryTask.copyWith(rawStatus: 'delivered');
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];

    final submitted = await controller.submitProof(
      _outForDeliveryTask,
      photo: _photo(),
    );

    expect(submitted, isFalse);
    expect(repository.proofExpectedRevisions, isEmpty);
    expect(
      controller.actionStatus(_outForDeliveryTask),
      DeliveryActionStatus.conflict,
    );
  });

  test(
    'proof ID is handed to a separate completion intent while pending',
    () async {
      final repository = _FakeDeliveryRepository();
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask];

      final proofSubmitted = await controller.submitProof(
        _outForDeliveryTask,
        photo: _photo(),
      );
      final completionSubmitted = await controller.submitCompletion(
        _outForDeliveryTask,
        evidenceId: controller.proofs[_outForDeliveryTask.id]!.proofId,
      );

      expect(proofSubmitted, isTrue);
      expect(completionSubmitted, isTrue);
      expect(repository.proofPhoto?.fileName, 'delivery.jpg');
      expect(repository.completionEvidenceId, 'proof-1');
      expect(
        repository.proofIdempotencyKeys.single ==
            repository.completionIdempotencyKeys.single,
        isFalse,
      );
      expect(
        controller.actionStatus(_outForDeliveryTask),
        DeliveryActionStatus.completionAwaitingValidation,
      );
      expect(
        controller.taskById(_outForDeliveryTask.id)?.status,
        PickupTaskStatus.outForDelivery,
      );
    },
  );

  test(
    'a stale completion projection cannot block the latest proof handoff',
    () async {
      final repository = _FakeDeliveryRepository()
        ..completionProjection = const CompletionProjection(
          taskId: 'delivery-task-1',
          intentId: 'old-intent',
          taskStatus: 'out_for_delivery',
          completionStatus: 'awaiting_validation',
          evidenceStatus: 'awaiting_validation',
          evidenceId: 'old-proof',
          revision: 7,
        );
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask]
        ..proofs[_outForDeliveryTask.id] = const ProofSubmission(
          taskId: 'delivery-task-1',
          proofId: 'new-proof',
          evidenceStatus: 'awaiting_validation',
          custodyState: 'out_for_delivery',
          completionEligible: false,
        );

      await controller.loadCompletion(_outForDeliveryTask);

      expect(controller.isCompletionPending(_outForDeliveryTask), isFalse);
      final submitted = await controller.submitCompletion(
        _outForDeliveryTask,
        evidenceId: 'new-proof',
      );

      expect(submitted, isTrue);
      expect(repository.completionEvidenceId, 'new-proof');
      expect(controller.isCompletionPending(_outForDeliveryTask), isTrue);
    },
  );

  test(
    'completion contract failures identify the safe response field',
    () async {
      final repository = _FakeDeliveryRepository()
        ..completionError = const ApiContractException(
          'delivery.completion.completion_status',
        );
      final controller = DeliveryController(deliveryRepository: repository)
        ..proofs[_outForDeliveryTask.id] = const ProofSubmission(
          taskId: 'delivery-task-1',
          proofId: 'proof-1',
          evidenceStatus: 'awaiting_validation',
          custodyState: 'out_for_delivery',
          completionEligible: false,
        );

      final submitted = await controller.submitCompletion(
        _outForDeliveryTask,
        evidenceId: 'proof-1',
      );

      expect(submitted, isFalse);
      expect(
        controller.actionError(_outForDeliveryTask),
        contains('data.completion_status'),
      );
    },
  );

  test('photo proof rejects an empty file locally', () async {
    final repository = _FakeDeliveryRepository();
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];

    final submitted = await controller.submitProof(
      _outForDeliveryTask,
      photo: DeliveryPhotoSelection(
        path: null,
        fileName: 'empty.jpg',
        bytes: Uint8List(0),
      ),
    );

    expect(submitted, isFalse);
    expect(repository.proofPhoto, isNull);
    expect(controller.actionError(_outForDeliveryTask), contains('non-empty'));
  });

  test(
    'server photo rejection is displayed without retaining an attempt',
    () async {
      final repository = _FakeDeliveryRepository()
        ..proofError = const ApiException(
          statusCode: 404,
          code: 'PARCEL_NOT_FOUND',
          message: 'not found',
        );
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = <PickupTask>[_outForDeliveryTask];

      final submitted = await controller.submitProof(
        _outForDeliveryTask,
        photo: _photo(),
      );

      expect(submitted, isFalse);
      expect(repository.proofPhoto?.fileName, 'delivery.jpg');
      expect(controller.hasPendingProof(_outForDeliveryTask), isFalse);
      expect(
        controller.actionError(_outForDeliveryTask),
        contains('parcel for this delivery task was not found'),
      );
    },
  );

  test('stale proof revision requires refresh before a new attempt', () async {
    final repository = _FakeDeliveryRepository()
      ..proofError = const ApiException(
        statusCode: 409,
        code: 'TASK_STATE_CONFLICT',
        message: 'stale',
      );
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];

    final first = await controller.submitProof(
      _outForDeliveryTask,
      photo: _photo(),
    );
    expect(first, isFalse);
    expect(
      controller.actionStatus(_outForDeliveryTask),
      DeliveryActionStatus.conflict,
    );

    repository
      ..proofError = null
      ..listedTask = _outForDeliveryTask.copyWith(revision: 8);
    await controller.load();
    final refreshedTask = controller.taskById(_outForDeliveryTask.id)!;
    final retry = await controller.submitProof(refreshedTask, photo: _photo());

    expect(retry, isTrue);
    expect(repository.proofExpectedRevisions, <int>[7, 8]);
    expect(
      repository.proofIdempotencyKeys.first ==
          repository.proofIdempotencyKeys.last,
      isFalse,
    );
  });

  test('offline proof retry preserves the exact request and key', () async {
    final repository = _FakeDeliveryRepository()
      ..proofError = const ApiException.network('offline');
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];

    final first = await controller.submitProof(
      _outForDeliveryTask,
      photo: _photo(),
    );
    repository.proofError = null;
    final retry = await controller.retryProof(_outForDeliveryTask);

    expect(first, isFalse);
    expect(retry, isTrue);
    expect(repository.proofIdempotencyKeys.length, 2);
    expect(
      repository.proofIdempotencyKeys.first,
      repository.proofIdempotencyKeys.last,
    );
    expect(repository.proofExpectedRevisions, <int>[7, 7]);
  });

  test('completion uses the latest known server revision', () async {
    final repository = _FakeDeliveryRepository()
      ..completionProjection = const CompletionProjection(
        taskId: 'delivery-task-1',
        taskStatus: 'out_for_delivery',
        completionStatus: null,
        evidenceStatus: 'awaiting_validation',
        evidenceId: 'proof-1',
        revision: 9,
      );
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask]
      ..proofs[_outForDeliveryTask.id] = const ProofSubmission(
        taskId: 'delivery-task-1',
        proofId: 'proof-1',
        evidenceStatus: 'awaiting_validation',
        custodyState: 'out_for_delivery',
        completionEligible: false,
      );

    final submitted = await controller.submitCompletion(
      _outForDeliveryTask,
      evidenceId: 'proof-1',
    );

    expect(submitted, isTrue);
    expect(repository.completionExpectedRevisions, <int>[9]);
  });

  test('rate-limited proof can retry the retained request', () async {
    final repository = _FakeDeliveryRepository()
      ..proofError = const ApiException(
        statusCode: 429,
        code: 'TOO_MANY_REQUESTS',
        message: 'slow down',
      );
    final controller = DeliveryController(deliveryRepository: repository)
      ..tasks = <PickupTask>[_outForDeliveryTask];

    final first = await controller.submitProof(
      _outForDeliveryTask,
      photo: _photo(),
    );
    repository.proofError = null;
    final retry = await controller.retryProof(_outForDeliveryTask);

    expect(first, isFalse);
    expect(retry, isTrue);
    expect(
      repository.proofIdempotencyKeys.first,
      repository.proofIdempotencyKeys.last,
    );
  });

  test('completion timeout reuses the same idempotency key', () async {
    final repository = _FakeDeliveryRepository()..failCompletionOnce = true;
    final controller = DeliveryController(deliveryRepository: repository);
    controller.proofs[_outForDeliveryTask.id] = const ProofSubmission(
      taskId: 'delivery-task-1',
      proofId: 'proof-1',
      evidenceStatus: 'awaiting_validation',
      custodyState: 'out_for_delivery',
      completionEligible: false,
    );

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
  Object? proofError;
  Object? completionError;
  bool failCompletionOnce = false;
  bool failMovementOnce = false;
  String? movementStatus;
  DeliveryPhotoSelection? proofPhoto;
  String? completionEvidenceId;
  CompletionProjection completionProjection = const CompletionProjection(
    taskId: 'delivery-task-1',
    taskStatus: 'out_for_delivery',
    completionStatus: null,
    evidenceStatus: 'awaiting_validation',
    evidenceId: 'proof-1',
    revision: 7,
  );
  PickupTask listedTask = _outForDeliveryTask;
  final List<int> proofExpectedRevisions = <int>[];
  final List<int> completionExpectedRevisions = <int>[];
  final List<String> proofIdempotencyKeys = <String>[];
  final List<String> movementIdempotencyKeys = <String>[];
  final List<String> completionIdempotencyKeys = <String>[];

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    if (loadError != null) {
      throw loadError!;
    }
    return <PickupTask>[listedTask];
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    if (loadError != null) throw loadError!;
    return listedTask;
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
    required String idempotencyKey,
  }) async {
    movementStatus = status;
    movementIdempotencyKeys.add(idempotencyKey);
    if (failMovementOnce) {
      failMovementOnce = false;
      throw const ApiException.network('offline');
    }
    return DeliveryStatusUpdate(
      taskId: taskId,
      status: status,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    proofPhoto = photo;
    proofExpectedRevisions.add(expectedRevision);
    proofIdempotencyKeys.add(idempotencyKey);
    if (proofError != null) {
      throw proofError!;
    }
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
    return completionProjection;
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
  }) async {
    completionEvidenceId = evidenceId;
    completionExpectedRevisions.add(expectedRevision);
    completionIdempotencyKeys.add(idempotencyKey);
    if (completionError != null) {
      throw completionError!;
    }
    if (failCompletionOnce) {
      failCompletionOnce = false;
      throw const ApiException.network(
        'timed out',
        networkFailure: ApiNetworkFailure.timeout,
      );
    }
    return CompletionProjection(
      taskId: 'delivery-task-1',
      intentId: 'intent-1',
      taskStatus: 'out_for_delivery',
      completionStatus: 'awaiting_validation',
      evidenceStatus: 'awaiting_validation',
      evidenceId: evidenceId,
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
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
);

DeliveryPhotoSelection _photo() => DeliveryPhotoSelection(
  path: null,
  fileName: 'delivery.jpg',
  bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
);
