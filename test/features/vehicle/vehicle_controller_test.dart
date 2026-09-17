import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/vehicle/data/vehicle_repository.dart';
import 'package:aisley_app/features/vehicle/domain/vehicle_models.dart';
import 'package:aisley_app/features/vehicle/presentation/vehicle_controller.dart';

void main() {
  test('saves only dirty fields and keeps the server revision', () async {
    final repository = _FakeVehicleRepository();
    final controller = VehicleController(vehicleRepository: repository);
    await controller.load();

    final saved = await controller.updateVehicle(
      changes: const <String, Object?>{'plate_number': 'XYZ-9876'},
    );

    expect(saved, isTrue);
    expect(repository.updateCalls.single.changes, <String, Object?>{
      'plate_number': 'XYZ-9876',
    });
    expect(repository.updateCalls.single.expectedRevision, 4);
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(repository.updateCalls.single.idempotencyKey),
      isTrue,
    );
    expect(controller.vehicle?.revision, 5);
    expect(controller.updateStatus, VehicleActionStatus.saved);
  });

  test('preserves field-addressable validation errors', () async {
    final repository = _FakeVehicleRepository()
      ..updateOutcomes.add(
        const ApiException(
          statusCode: 422,
          code: 'VALIDATION_ERROR',
          message: 'invalid',
          fieldErrors: <String, List<String>>{
            'plate_number': <String>['This plate is already registered.'],
          },
        ),
      );
    final controller = VehicleController(vehicleRepository: repository);
    await controller.load();

    final saved = await controller.updateVehicle(
      changes: const <String, Object?>{'plate_number': 'DUPLICATE'},
    );

    expect(saved, isFalse);
    expect(controller.updateStatus, VehicleActionStatus.validationError);
    expect(
      controller.updateFieldErrors['plate_number']?.single,
      contains('already'),
    );
    expect(controller.hasPendingUpdate, isFalse);
  });

  test('keeps the same update attempt after an uncertain response', () async {
    final repository = _FakeVehicleRepository()
      ..updateOutcomes.addAll(<Object>[
        const ApiException.network('timed out'),
        _vehicle(revision: 5),
      ]);
    final controller = VehicleController(vehicleRepository: repository);
    await controller.load();

    final firstAttempt = await controller.updateVehicle(
      changes: const <String, Object?>{'model': 'New Model'},
    );
    final firstKey = repository.updateCalls.single.idempotencyKey;
    final secondAttempt = await controller.retryUpdate();

    expect(firstAttempt, isFalse);
    expect(secondAttempt, isTrue);
    expect(repository.fetchCount, 2);
    expect(repository.updateCalls, hasLength(2));
    expect(repository.updateCalls[1].idempotencyKey, firstKey);
    expect(controller.vehicle?.revision, 5);
  });

  test('refreshes the vehicle after a stale revision conflict', () async {
    final repository = _FakeVehicleRepository()
      ..updateOutcomes.add(
        const ApiException(
          statusCode: 409,
          code: 'VEHICLE_REVISION_CONFLICT',
          message: 'stale revision',
        ),
      );
    final controller = VehicleController(vehicleRepository: repository);
    await controller.load();
    repository.vehicle = _vehicle(revision: 6, plateNumber: 'SERVER-PLATE');

    final saved = await controller.updateVehicle(
      changes: const <String, Object?>{'plate_number': 'LOCAL-PLATE'},
    );

    expect(saved, isFalse);
    expect(repository.updateCalls.single.expectedRevision, 4);
    expect(controller.updateStatus, VehicleActionStatus.conflict);
    expect(controller.vehicle?.revision, 6);
    expect(controller.vehicle?.plateNumber, 'SERVER-PLATE');
  });

  test(
    'hands a document upload to the exact document action independently',
    () async {
      final repository = _FakeVehicleRepository();
      final controller = VehicleController(vehicleRepository: repository);
      await controller.load();
      final selection = VehicleDocumentSelection(
        path: '/tmp/or.png',
        fileName: 'or.png',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      final uploaded = await controller.uploadDocument(
        VehicleDocumentKind.officialReceipt,
        selection,
      );

      expect(uploaded, isTrue);
      expect(
        repository.documentCalls.single.kind,
        VehicleDocumentKind.officialReceipt,
      );
      expect(repository.documentCalls.single.expectedRevision, 4);
      expect(repository.documentCalls.single.selection.fileName, 'or.png');
      expect(
        controller.documentActionStatus(VehicleDocumentKind.officialReceipt),
        VehicleActionStatus.uploaded,
      );
      expect(
        controller.documentActionStatus(
          VehicleDocumentKind.certificateOfRegistration,
        ),
        VehicleActionStatus.idle,
      );
    },
  );
}

class _FakeVehicleRepository implements VehicleRepository {
  CourierVehicle vehicle = _vehicle();
  final List<Object> updateOutcomes = <Object>[];
  final List<Object> documentOutcomes = <Object>[];
  final List<_UpdateCall> updateCalls = <_UpdateCall>[];
  final List<_DocumentCall> documentCalls = <_DocumentCall>[];
  int fetchCount = 0;

  @override
  Future<CourierVehicle> fetchVehicle() async {
    fetchCount += 1;
    return vehicle;
  }

  @override
  Future<CourierVehicle> updateVehicle({
    required Map<String, Object?> changes,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    updateCalls.add(
      _UpdateCall(
        changes: Map<String, Object?>.from(changes),
        expectedRevision: expectedRevision,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (updateOutcomes.isNotEmpty) {
      final outcome = updateOutcomes.removeAt(0);
      if (outcome is Exception) {
        throw outcome;
      }
    }
    vehicle = _vehicle(revision: vehicle.revision + 1);
    return vehicle;
  }

  @override
  Future<CourierVehicle> uploadDocument({
    required VehicleDocumentKind kind,
    required VehicleDocumentSelection selection,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    documentCalls.add(
      _DocumentCall(
        kind: kind,
        selection: selection,
        expectedRevision: expectedRevision,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (documentOutcomes.isNotEmpty) {
      final outcome = documentOutcomes.removeAt(0);
      if (outcome is Exception) {
        throw outcome;
      }
    }
    vehicle = _vehicle(revision: vehicle.revision + 1);
    return vehicle;
  }

  @override
  Future<VehicleDocumentData> fetchDocument(VehicleDocumentKind kind) async {
    return VehicleDocumentData(
      bytes: Uint8List.fromList(<int>[1]),
      contentType: 'image/png',
    );
  }
}

class _UpdateCall {
  const _UpdateCall({
    required this.changes,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final Map<String, Object?> changes;
  final int expectedRevision;
  final String idempotencyKey;
}

class _DocumentCall {
  const _DocumentCall({
    required this.kind,
    required this.selection,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final VehicleDocumentKind kind;
  final VehicleDocumentSelection selection;
  final int expectedRevision;
  final String idempotencyKey;
}

CourierVehicle _vehicle({int revision = 4, String plateNumber = 'ABC-1234'}) {
  return CourierVehicle(
    id: 'vehicle-1',
    vehicleType: 'motorcycle',
    plateNumber: plateNumber,
    make: 'Honda',
    model: 'Click',
    revision: revision,
    officialReceipt: const VehicleDocumentReference(
      id: 'or-1',
      url: '/api/v1/courier/vehicle/documents/official_receipt',
    ),
  );
}
