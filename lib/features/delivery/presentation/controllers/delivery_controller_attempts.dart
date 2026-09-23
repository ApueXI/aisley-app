part of 'delivery_controller.dart';

class _PendingMovementAttempt {
  const _PendingMovementAttempt({
    required this.targetStatus,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String targetStatus;
  final int expectedRevision;
  final String idempotencyKey;
}

class _PendingPhotoAttempt {
  const _PendingPhotoAttempt({
    required this.photo,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final DeliveryPhotoSelection photo;
  final int expectedRevision;
  final String idempotencyKey;
}

class _PendingCompletionAttempt {
  const _PendingCompletionAttempt({
    required this.evidenceId,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String evidenceId;
  final int expectedRevision;
  final String idempotencyKey;
}
