import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/batch/data/final_mile_batch_repository.dart';
import 'package:aisley_app/features/batch/domain/final_mile_batch_models.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';

void main() {
  test(
    'loads offers and refreshes dependent work after atomic acceptance',
    () async {
      final repository = _FakeBatchRepository();
      var refreshCount = 0;
      final controller = FinalMileBatchController(
        repository: repository,
        onBatchAccepted: () async => refreshCount++,
      );

      await controller.load();
      final result = await controller.accept('schedule-1');

      expect(result, isTrue);
      expect(controller.batches.single.status, FinalMileBatchStatus.accepted);
      expect(
        controller.actionStatus('schedule-1'),
        FinalMileBatchActionStatus.accepted,
      );
      expect(repository.acceptCalls, 1);
      expect(refreshCount, 1);
    },
  );

  test('reconciles a timeout before state-idempotent retry', () async {
    final repository = _FakeBatchRepository()..timeoutFirstAccept = true;
    final controller = FinalMileBatchController(repository: repository);
    await controller.load();

    final first = await controller.accept('schedule-1');
    final retry = await controller.retryAcceptance('schedule-1');

    expect(first, isFalse);
    expect(retry, isTrue);
    expect(repository.acceptCalls, 2);
    expect(repository.detailCalls, 2);
    expect(controller.batchById('schedule-1')?.isAccepted, isTrue);
  });

  test(
    'maps the documented batch conflict and refreshes current state',
    () async {
      final repository = _FakeBatchRepository()
        ..acceptError = const ApiException(
          statusCode: 409,
          code: 'BATCH_STATE_CONFLICT',
          message: 'member changed',
        );
      final controller = FinalMileBatchController(repository: repository);
      await controller.load();

      final result = await controller.accept('schedule-1');

      expect(result, isFalse);
      expect(
        controller.actionStatus('schedule-1'),
        FinalMileBatchActionStatus.conflict,
      );
      expect(controller.actionError('schedule-1'), contains('parcel'));
      expect(repository.detailCalls, 1);
    },
  );

  test('maps BATCH_NOT_FOUND to an unavailable detail', () async {
    final repository = _FakeBatchRepository()
      ..detailError = const ApiException(
        statusCode: 404,
        code: 'BATCH_NOT_FOUND',
        message: 'hidden',
      );
    final controller = FinalMileBatchController(repository: repository);

    await controller.loadDetail('missing-schedule');

    expect(
      controller.detailStatus('missing-schedule'),
      FinalMileBatchLoadStatus.unavailable,
    );
    expect(
      controller.detailError('missing-schedule'),
      contains('no longer available'),
    );
  });
}

class _FakeBatchRepository implements FinalMileBatchRepository {
  Object? acceptError;
  Object? detailError;
  bool timeoutFirstAccept = false;
  int acceptCalls = 0;
  int detailCalls = 0;

  @override
  Future<List<FinalMileBatch>> fetchBatches() async => <FinalMileBatch>[
    _batch(FinalMileBatchStatus.offered),
  ];

  @override
  Future<FinalMileBatch> fetchBatch(String scheduleId) async {
    detailCalls++;
    final error = detailError;
    if (error != null) throw error;
    return _batch(FinalMileBatchStatus.offered);
  }

  @override
  Future<FinalMileBatch> acceptBatch(String scheduleId) async {
    acceptCalls++;
    if (timeoutFirstAccept && acceptCalls == 1) {
      throw const ApiException.network(
        'timed out',
        networkFailure: ApiNetworkFailure.timeout,
      );
    }
    final error = acceptError;
    if (error != null) throw error;
    return _batch(FinalMileBatchStatus.accepted);
  }
}

FinalMileBatch _batch(FinalMileBatchStatus status) {
  return FinalMileBatch(
    id: 'schedule-1',
    reference: 'DSP-100',
    scheduledFor: DateTime.utc(2026, 9, 27, 1, 30),
    parcelCount: 1,
    status: status,
    tasks: const <FinalMileBatchTask>[
      FinalMileBatchTask(
        id: 'task-1',
        status: 'delivery_assigned',
        orderReference: 'ORD-100',
        parcel: FinalMileBatchParcel(
          id: 'parcel-1',
          reference: 'PAR-100',
          itemCount: 2,
          price: '800.00',
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
