part of 'pickup_controller.dart';

class _PendingPickupAttempt {
  const _PendingPickupAttempt({
    required this.leg,
    required this.identifierType,
    required this.identifier,
    required this.idempotencyKey,
  });

  final PickupTaskLeg leg;
  final String identifierType;
  final String identifier;
  final String idempotencyKey;
}

class _PendingRejectionAttempt {
  const _PendingRejectionAttempt({
    required this.reason,
    required this.idempotencyKey,
  });

  final String reason;
  final String idempotencyKey;
}
