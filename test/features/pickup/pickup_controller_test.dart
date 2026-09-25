import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';

void main() {
  test('loads first-mile and final-mile work as separate sections', () async {
    final repository = _FakePickupRepository();
    final controller = PickupController(pickupRepository: repository);

    await controller.load();

    expect(controller.firstMileStatus, PickupSectionStatus.loaded);
    expect(controller.finalMileStatus, PickupSectionStatus.loaded);
    expect(controller.firstMileTasks.single.leg, PickupTaskLeg.firstMile);
    expect(controller.finalMileTasks.single.leg, PickupTaskLeg.finalMile);
  });

  test('acceptance replaces the task with the server state', () async {
    final repository = _FakePickupRepository();
    final controller = PickupController(pickupRepository: repository);
    await controller.load();

    final task = controller.firstMileTasks.single;
    final accepted = await controller.acceptTask(task);

    expect(accepted, isTrue);
    expect(controller.firstMileTasks.single.rawStatus, 'accepted');
    expect(controller.actionStatus(task), PickupTaskActionStatus.accepted);
  });

  test('normal final-mile task cannot be accepted individually', () async {
    final repository = _FakePickupRepository();
    final controller = PickupController(pickupRepository: repository);
    final offered = _finalMileTask.copyWith(rawStatus: 'delivery_assigned');

    final accepted = await controller.acceptTask(offered);

    expect(accepted, isFalse);
    expect(repository.finalMileAcceptCalled, isFalse);
  });

  test(
    'retries uncertain first-mile pickup with the same idempotency key',
    () async {
      final repository = _FakePickupRepository()
        ..firstMilePickupError = const ApiException.network(
          'timed out',
          networkFailure: ApiNetworkFailure.timeout,
        )
        ..failFirstMilePickupOnce = true;
      final controller = PickupController(pickupRepository: repository);
      await controller.load();

      final task = controller.firstMileTasks.single.copyWith(
        rawStatus: 'accepted',
      );
      final first = await controller.confirmFirstMilePickup(
        task,
        identifierType: 'qr',
        identifier: 'AISLEY:WB:1:WB-100',
      );
      final retry = await controller.retryFirstMilePickup(task);

      expect(first, isFalse);
      expect(retry, isTrue);
      expect(repository.firstMileIdempotencyKeys.length, 2);
      expect(
        repository.firstMileIdempotencyKeys.first,
        repository.firstMileIdempotencyKeys.last,
      );
      expect(controller.actionStatus(task), PickupTaskActionStatus.succeeded);
      expect(controller.lastFirstMilePickup?.orderStatus, 'picked_up');
    },
  );

  test('keeps final-mile pickup pending until Logistics validation', () async {
    final repository = _FakePickupRepository();
    final controller = PickupController(pickupRepository: repository);
    await controller.load();
    final task = controller.finalMileTasks.single;

    final submitted = await controller.submitFinalMilePickup(task);

    expect(submitted, isTrue);
    expect(
      controller.actionStatus(task),
      PickupTaskActionStatus.awaitingValidation,
    );
    expect(controller.finalMileTasks.single.rawStatus, 'delivery_accepted');
    expect(
      controller.lastFinalMilePickup?.evidenceStatus,
      'awaiting_validation',
    );
  });

  test('records a final-mile rejection without changing the Order', () async {
    final repository = _FakePickupRepository();
    final controller = PickupController(pickupRepository: repository);
    await controller.load();
    final task = controller.finalMileTasks.single.copyWith(
      rawStatus: 'delivery_assigned',
    );
    controller.finalMileTasks = <PickupTask>[task];

    final rejected = await controller.rejectFinalMileTask(
      task,
      reason: 'Vehicle unavailable',
    );

    expect(rejected, isTrue);
    expect(controller.finalMileTasks.single.rawStatus, 'rejected');
    expect(
      controller.finalMileTasks.single.rejectionReason,
      'Vehicle unavailable',
    );
    expect(controller.actionStatus(task), PickupTaskActionStatus.rejected);
  });

  test(
    'policy consent denial is explicit and does not clear a valid session',
    () async {
      final repository = _FakePickupRepository()
        ..firstMileLoadError = const ApiException(
          statusCode: 403,
          code: 'POLICY_CONSENT_REQUIRED',
          message: 'consent required',
        )
        ..finalMileLoadError = const ApiException(
          statusCode: 403,
          code: 'POLICY_CONSENT_REQUIRED',
          message: 'consent required',
        );
      var authFailureCalled = false;
      final controller = PickupController(
        pickupRepository: repository,
        onAuthFailure: (_) async {
          authFailureCalled = true;
        },
      );

      await controller.load();

      expect(controller.firstMileStatus, PickupSectionStatus.consentRequired);
      expect(controller.finalMileStatus, PickupSectionStatus.consentRequired);
      expect(authFailureCalled, isFalse);
    },
  );

  test('401 is delegated to the auth boundary', () async {
    final repository = _FakePickupRepository()
      ..firstMileLoadError = const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'expired',
      );
    ApiException? authFailure;
    final controller = PickupController(
      pickupRepository: repository,
      onAuthFailure: (error) async {
        authFailure = error;
      },
    );

    await controller.load();

    expect(controller.firstMileStatus, PickupSectionStatus.unauthorized);
    expect(authFailure?.statusCode, 401);
  });
}

class _FakePickupRepository implements PickupRepository {
  Object? firstMileLoadError;
  Object? finalMileLoadError;
  Object? firstMilePickupError;
  bool failFirstMilePickupOnce = false;
  bool finalMileAcceptCalled = false;
  final List<String> firstMileIdempotencyKeys = <String>[];

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    if (firstMileLoadError != null) {
      throw firstMileLoadError!;
    }
    return FirstMileTaskPage(tasks: <PickupTask>[_firstMileTask]);
  }

  @override
  Future<PickupTask> acceptFirstMileTask(String taskId) async {
    return _firstMileTask.copyWith(rawStatus: 'accepted');
  }

  @override
  Future<WaybillResolution> resolveWaybill(String payload) async {
    return const WaybillResolution(
      taskId: 'task-1',
      orderId: 'order-1',
      orderReference: 'ORD-100',
      waybillReference: 'WB-100',
    );
  }

  @override
  Future<FirstMilePickupResult> confirmFirstMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required String idempotencyKey,
  }) async {
    firstMileIdempotencyKeys.add(idempotencyKey);
    if (failFirstMilePickupOnce) {
      failFirstMilePickupOnce = false;
      throw firstMilePickupError!;
    }
    return const FirstMilePickupResult(
      taskId: 'task-1',
      taskStatus: 'picked_up_from_seller',
      orderStatus: 'picked_up',
      pickedUpAt: null,
    );
  }

  @override
  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId) async {
    return const PickupRouteManifest(status: RouteManifestStatus.pending);
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    if (finalMileLoadError != null) {
      throw finalMileLoadError!;
    }
    return <PickupTask>[_finalMileTask];
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    return _finalMileTask;
  }

  @override
  Future<PickupTask> acceptFinalMileTask(String taskId) async {
    finalMileAcceptCalled = true;
    return _finalMileTask.copyWith(rawStatus: 'delivery_accepted');
  }

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

const _firstMileTask = PickupTask(
  id: 'task-1',
  leg: PickupTaskLeg.firstMile,
  rawStatus: 'assigned',
  order: PickupOrderReference(id: 'order-1', reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  pickupScheduleId: 'schedule-1',
  schedule: PickupSchedule(id: 'schedule-1', reference: 'SCH-100'),
);

const _finalMileTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'delivery_accepted',
  revision: 4,
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  pickup: PickupLocation(name: 'Makati Hub'),
);
