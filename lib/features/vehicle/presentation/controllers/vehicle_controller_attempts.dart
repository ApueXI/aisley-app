part of 'vehicle_controller.dart';

class _PendingVehicleUpdate {
  const _PendingVehicleUpdate({
    required this.changes,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final Map<String, Object?> changes;
  final int expectedRevision;
  final String idempotencyKey;
}

class _PendingDocumentUpload {
  const _PendingDocumentUpload({
    required this.selection,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final VehicleDocumentSelection selection;
  final int expectedRevision;
  final String idempotencyKey;
}
