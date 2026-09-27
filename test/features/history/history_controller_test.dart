import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/delivery/domain/delivery_proof_photo.dart';
import 'package:aisley_app/features/history/data/history_repository.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';

void main() {
  test('history detail loads its authenticated private proof bytes', () async {
    final repository = _FakeHistoryRepository();
    final controller = HistoryController(historyRepository: repository);

    await controller.loadDetail('delivery-task-1');

    expect(repository.photoReads, <String>['proof-1']);
    expect(controller.detailProofId, 'proof-1');
    expect(controller.detailProofPhoto?.contentType, 'image/jpeg');
    expect(controller.detailProofPhotoStatus, ProofPhotoLoadStatus.loaded);
  });

  test(
    'preview failure does not replace the delivered history record',
    () async {
      final repository = _FakeHistoryRepository()
        ..photoError = const ApiException.network('offline');
      final controller = HistoryController(historyRepository: repository);

      await controller.loadDetail('delivery-task-1');

      expect(controller.detail?.status, 'delivered');
      expect(controller.detailStatus, HistoryLoadStatus.loaded);
      expect(controller.detailProofPhoto, isNull);
      expect(controller.detailProofPhotoStatus, ProofPhotoLoadStatus.offline);
      expect(controller.detailProofPhotoError, contains('offline'));
    },
  );

  test('detail close clears private proof bytes from memory', () async {
    final controller = HistoryController(
      historyRepository: _FakeHistoryRepository(),
    );
    await controller.loadDetail('delivery-task-1');

    controller.clearDetail();

    expect(controller.detail, isNull);
    expect(controller.detailProofPhoto, isNull);
    expect(controller.detailProofId, isNull);
    expect(controller.detailProofPhotoStatus, ProofPhotoLoadStatus.idle);
  });

  test('photo authorization loss invokes the account auth boundary', () async {
    ApiException? authFailure;
    final repository = _FakeHistoryRepository()
      ..photoError = const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'expired',
      );
    final controller = HistoryController(
      historyRepository: repository,
      onAuthFailure: (error) async => authFailure = error,
    );

    await controller.loadDetail('delivery-task-1');

    expect(controller.detailProofPhoto, isNull);
    expect(
      controller.detailProofPhotoStatus,
      ProofPhotoLoadStatus.unauthorized,
    );
    expect(authFailure?.statusCode, 401);
  });
}

class _FakeHistoryRepository implements HistoryRepository {
  Object? photoError;
  final List<String> photoReads = <String>[];

  @override
  Future<DeliveryHistoryItem> fetchDetail(String taskId) async => _historyItem;

  @override
  Future<DeliveryHistoryPage> fetchHistory({
    String? reference,
    int limit = 20,
  }) async {
    return const DeliveryHistoryPage(
      items: <DeliveryHistoryItem>[_historyItem],
    );
  }

  @override
  Future<DeliveryProofPhoto> fetchProofPhoto(String proofId) async {
    photoReads.add(proofId);
    if (photoError != null) throw photoError!;
    return DeliveryProofPhoto(
      bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
      contentType: 'image/jpeg',
    );
  }
}

const _historyItem = DeliveryHistoryItem(
  taskId: 'delivery-task-1',
  status: 'delivered',
  evidenceId: 'proof-1',
  evidenceStatus: 'validated',
  completionStatus: 'validated',
);
