part of 'delivery_controller.dart';

extension DeliveryControllerActions on DeliveryController {
  Future<bool> advanceStatus(PickupTask task) async {
    final nextStatus = DeliveryController.nextStatusFor(task.status);
    final revision = task.revision;
    if (!task.isFinalMile || nextStatus == null || revision == null) {
      return false;
    }
    final taskId = task.id;
    if (!canStartAction(task)) {
      return false;
    }
    _actionStatuses[taskId] = DeliveryActionStatus.moving;
    _actionErrors[taskId] = null;
    _actionRetryAfter[taskId] = null;
    _notifyDeliveryListeners();
    try {
      final update = await deliveryRepository.advanceStatus(
        taskId: taskId,
        status: nextStatus,
        expectedRevision: revision,
      );
      final updated = task.copyWith(
        rawStatus: update.status,
        revision: update.revision,
      );
      _replaceTask(updated);
      final context = contexts[taskId];
      if (context != null) {
        contexts[taskId] = context.copyWith(
          status: update.status,
          revision: update.revision,
        );
      }
      _actionStatuses[taskId] = DeliveryActionStatus.moved;
      _notifyDeliveryListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }

  Future<bool> submitProof(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    final normalizedIdentifier = identifierType == 'qr'
        ? identifier
        : identifier.trim();
    if (task.revision == null) {
      _setLocalValidationError(
        task,
        'The task revision is unavailable. Refresh the task before submitting proof.',
      );
      return false;
    }
    if (!DeliveryController._validIdentifier(
      identifierType,
      normalizedIdentifier,
    )) {
      _setLocalValidationError(
        task,
        'Choose QR or enter a public Order reference up to 128 characters.',
      );
      return false;
    }
    if (identifierType == 'order_id') {
      final publicOrderReference = task.order?.reference?.trim();
      if (publicOrderReference == null || publicOrderReference.isEmpty) {
        _setLocalValidationError(
          task,
          'The public Order reference is unavailable. Use the delivery QR instead.',
        );
        return false;
      }
      final orderDatabaseId = task.order?.id?.trim();
      final waybillReference = task.waybill?.reference?.trim();
      final waybillDatabaseId = task.waybill?.id?.trim();
      if (normalizedIdentifier == orderDatabaseId ||
          normalizedIdentifier == waybillReference ||
          normalizedIdentifier == waybillDatabaseId) {
        _setLocalValidationError(
          task,
          'Enter the public Order reference shown above. Database IDs and waybill references are not accepted here.',
        );
        return false;
      }
    }
    final existing = _pendingProofs[task.id];
    final attempt =
        existing != null &&
            existing.identifierType == identifierType &&
            existing.identifier == normalizedIdentifier
        ? existing
        : _PendingIdentifierAttempt(
            identifierType: identifierType,
            identifier: normalizedIdentifier,
            expectedRevision: task.revision!,
            idempotencyKey: DeliveryController._newUuid(),
          );
    _pendingProofs[task.id] = attempt;
    return _performProof(task, attempt);
  }

  Future<bool> retryProof(PickupTask task) async {
    final attempt = _pendingProofs[task.id];
    if (attempt == null) {
      return false;
    }
    return _performProof(task, attempt);
  }

  Future<bool> _performProof(
    PickupTask task,
    _PendingIdentifierAttempt attempt,
  ) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.proofSubmitting;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();
    try {
      final proof = await deliveryRepository.submitProof(
        taskId: task.id,
        identifierType: attempt.identifierType,
        identifier: attempt.identifier,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
      );
      proofs[task.id] = proof;
      _pendingProofs.remove(task.id);
      _actionStatuses[task.id] = DeliveryActionStatus.proofAwaitingValidation;
      _notifyDeliveryListeners();
      return true;
    } on ApiException catch (error) {
      if (DeliveryController._isDefinitiveMutationError(error)) {
        _pendingProofs.remove(task.id);
      }
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }

  Future<bool> submitCompletion(
    PickupTask task, {
    required String evidenceId,
  }) async {
    final normalizedEvidenceId = evidenceId.trim();
    final latestRevision = _latestRevision(task);
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        latestRevision == null ||
        normalizedEvidenceId.isEmpty ||
        isCompletionPending(task) ||
        completions[task.id]?.isDelivered == true ||
        !canStartAction(task)) {
      return false;
    }
    final knownProofId =
        proofs[task.id]?.proofId ?? completions[task.id]?.evidenceId;
    if (knownProofId == null || knownProofId != normalizedEvidenceId) {
      _setLocalValidationError(
        task,
        'Submit proof for this delivery first. Only its server-returned proof ID can be used for completion.',
      );
      return false;
    }
    final existing = _pendingCompletions[task.id];
    final attempt =
        existing != null && existing.evidenceId == normalizedEvidenceId
        ? existing
        : _PendingCompletionAttempt(
            evidenceId: normalizedEvidenceId,
            expectedRevision: latestRevision,
            idempotencyKey: DeliveryController._newUuid(),
          );
    _pendingCompletions[task.id] = attempt;
    return _performCompletion(task, attempt);
  }

  Future<bool> retryCompletion(PickupTask task) async {
    final attempt = _pendingCompletions[task.id];
    if (attempt == null) {
      return false;
    }
    return _performCompletion(task, attempt);
  }

  Future<bool> _performCompletion(
    PickupTask task,
    _PendingCompletionAttempt attempt,
  ) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        completions[task.id]?.isDelivered == true ||
        !canStartAction(task)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.completionSubmitting;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();
    try {
      final completion = await deliveryRepository.submitCompletion(
        taskId: task.id,
        expectedRevision: attempt.expectedRevision,
        evidenceId: attempt.evidenceId,
        idempotencyKey: attempt.idempotencyKey,
      );
      completions[task.id] = completion;
      _pendingCompletions.remove(task.id);
      _syncTaskFromCompletion(task, completion, allowDelivered: false);
      _actionStatuses[task.id] =
          DeliveryActionStatus.completionAwaitingValidation;
      _notifyDeliveryListeners();
      return true;
    } on ApiException catch (error) {
      if (DeliveryController._isDefinitiveMutationError(error)) {
        _pendingCompletions.remove(task.id);
      }
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }
}
