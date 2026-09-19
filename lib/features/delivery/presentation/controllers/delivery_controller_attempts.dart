part of 'delivery_controller.dart';

class _PendingIdentifierAttempt {
  const _PendingIdentifierAttempt({
    required this.identifierType,
    required this.identifier,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String identifierType;
  final String identifier;
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
