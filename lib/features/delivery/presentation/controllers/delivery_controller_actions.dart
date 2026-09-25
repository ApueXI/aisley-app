part of 'delivery_controller.dart';

extension DeliveryControllerActions on DeliveryController {
  Future<bool> advanceStatus(PickupTask task) async {
    final nextStatus = DeliveryController.nextStatusFor(task.status);
    final revision = task.revision;
    if (!task.isFinalMile ||
        nextStatus == null ||
        revision == null ||
        !canStartAction(task)) {
      return false;
    }
    final pending = _pendingMovements[task.id];
    if (pending != null &&
        (pending.targetStatus != nextStatus ||
            pending.expectedRevision != revision)) {
      _pendingMovements.remove(task.id);
    }
    final attempt =
        _pendingMovements[task.id] ??
        _PendingMovementAttempt(
          targetStatus: nextStatus,
          expectedRevision: revision,
          idempotencyKey: DeliveryController._newUuid(),
        );
    _pendingMovements[task.id] = attempt;
    return _performMovement(task, attempt);
  }

  Future<bool> retryMovement(PickupTask task) async {
    final attempt = _pendingMovements[task.id];
    if (attempt == null || !canStartAction(task)) {
      return false;
    }
    try {
      final tasks = await deliveryRepository.fetchFinalMileTasks();
      PickupTask? fresh;
      for (final candidate in tasks) {
        if (candidate.id == task.id) {
          fresh = candidate;
          break;
        }
      }
      if (fresh == null) {
        _actionStatuses[task.id] = DeliveryActionStatus.failed;
        _actionErrors[task.id] = 'This task is no longer in your active delivery list. Refresh your work.';
        _notifyDeliveryListeners();
        return false;
      }
      _replaceTask(fresh);
      if (fresh.rawStatus == attempt.targetStatus) {
        _pendingMovements.remove(task.id);
        _actionStatuses[task.id] = DeliveryActionStatus.moved;
        _actionErrors[task.id] = null;
        _notifyDeliveryListeners();
        return true;
      }
      if (fresh.rawStatus != task.rawStatus ||
          fresh.revision != attempt.expectedRevision) {
        _pendingMovements.remove(task.id);
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery state changed. Review the refreshed task before acting.';
        _notifyDeliveryListeners();
        return false;
      }
      return await _performMovement(fresh, attempt);
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }

  Future<bool> _performMovement(
    PickupTask task,
    _PendingMovementAttempt attempt,
  ) async {
    final taskId = task.id;
    _actionStatuses[taskId] = DeliveryActionStatus.moving;
    _actionErrors[taskId] = null;
    _actionRetryAfter[taskId] = null;
    _notifyDeliveryListeners();
    try {
      final update = await deliveryRepository.advanceStatus(
        taskId: taskId,
        status: attempt.targetStatus,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
      );
      if (update.taskId != taskId || update.status != attempt.targetStatus) {
        throw const ApiContractException('delivery.status.task_projection');
      }
      final updated = task.copyWith(
        rawStatus: update.status,
        revision: update.revision,
      );
      _pendingMovements.remove(taskId);
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
      if (DeliveryController._isDefinitiveMutationError(error)) {
        _pendingMovements.remove(taskId);
      }
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
    required DeliveryPhotoSelection photo,
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    final priorProof = proofs[task.id];
    if (priorProof != null && evidenceStatusFor(task) != 'rejected') {
      _setLocalValidationError(
        task,
        'This task already has photo proof. Refresh its validation status before submitting another.',
      );
      return false;
    }
    if (photo.bytes.isEmpty ||
        photo.bytes.length >= maxImageUploadBytes ||
        photo.fileName.trim().isEmpty) {
      _setLocalValidationError(
        task,
        'Choose a non-empty JPEG, PNG, or WebP photo under 10 MiB.',
      );
      return false;
    }
    if (_pendingProofs.containsKey(task.id)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.loading;
    _actionErrors[task.id] = null;
    _notifyDeliveryListeners();
    PickupTask current;
    try {
      current = await deliveryRepository.fetchFinalMileTask(task.id);
      if (current.id != task.id || !current.isFinalMile) {
        throw const ApiContractException('delivery.task.identity');
      }
      _replaceTask(current);
      if (current.status != PickupTaskStatus.outForDelivery ||
          current.revision == null) {
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery task or its revision changed. Refresh before submitting photo proof.';
        _notifyDeliveryListeners();
        return false;
      }
    } on ApiException catch (error) {
      await _setActionError(task, error);
      return false;
    } on TokenStorageException {
      _setStorageActionError(task);
      return false;
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
      return false;
    }
    final attempt = _PendingPhotoAttempt(
      photo: photo,
      expectedRevision: current.revision!,
      idempotencyKey: DeliveryController._newUuid(),
    );
    _pendingProofs[task.id] = attempt;
    _actionStatuses[task.id] = DeliveryActionStatus.idle;
    return _performProof(current, attempt, onCancel: onCancel);
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
    _PendingPhotoAttempt attempt, {
    void Function(void Function() cancel)? onCancel,
  }) async {
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
        photo: attempt.photo,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
        onCancel: onCancel,
      );
      if (proof.taskId != task.id) {
        throw const ApiContractException('delivery.proof.task_id');
      }
      proofs[task.id] = proof;
      _pendingProofs.remove(task.id);
      _actionStatuses[task.id] = proof.evidenceStatus == 'rejected'
          ? DeliveryActionStatus.validationError
          : DeliveryActionStatus.proofAwaitingValidation;
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
    required DeliveryCodCollection confirmedCollection,
  }) async {
    final normalizedEvidenceId = evidenceId.trim();
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
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
    if (completions[task.id]?.evidenceId == normalizedEvidenceId &&
        completions[task.id]?.evidenceStatus == 'rejected') {
      _setLocalValidationError(
        task,
        'Logistics rejected this photo. Select and submit a new photo POD.',
      );
      return false;
    }
    final existing = _pendingCompletions[task.id];
    if (existing != null && existing.evidenceId == normalizedEvidenceId) {
      return _performCompletion(task, existing);
    }
    final currentCollection = await _readCodCollection(task);
    if (currentCollection == null) return false;
    if (!currentCollection.matches(confirmedCollection)) {
      _setLocalValidationError(
        task,
        'The COD amount changed. Review the current payable total and confirm collection again.',
      );
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.completionLoading;
    _actionErrors[task.id] = null;
    _notifyDeliveryListeners();
    CompletionProjection current;
    try {
      current = await deliveryRepository.fetchCompletion(task.id);
      if (current.taskId != task.id) {
        throw const ApiContractException('delivery.completion.task_id');
      }
      completions[task.id] = current;
      if (current.evidenceId == normalizedEvidenceId &&
          (current.evidenceStatus == 'rejected' ||
              current.completionStatus == 'rejected')) {
        _actionStatuses[task.id] = DeliveryActionStatus.validationError;
        _actionErrors[task.id] = 'Logistics rejected this photo or intent. Submit a new photo proof.';
        _notifyDeliveryListeners();
        return false;
      }
      if (current.isDelivered ||
          (current.isAwaitingValidation &&
              _completionMatchesCurrentProof(task.id, current))) {
        _syncTaskFromCompletion(task, current);
        _reconcileActionWithCompletion(task.id, current);
        _notifyDeliveryListeners();
        return false;
      }
      if (current.revision == null ||
          current.taskStatus != 'out_for_delivery') {
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'The task revision or state changed. Refresh before submitting completion.';
        _notifyDeliveryListeners();
        return false;
      }
    } on ApiException catch (error) {
      await _setActionError(task, error);
      return false;
    } on TokenStorageException {
      _setStorageActionError(task);
      return false;
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
      return false;
    }
    final attempt = _PendingCompletionAttempt(
      evidenceId: normalizedEvidenceId,
      expectedRevision: current.revision!,
      idempotencyKey: DeliveryController._newUuid(),
      codCollected: true,
    );
    _pendingCompletions[task.id] = attempt;
    _actionStatuses[task.id] = DeliveryActionStatus.idle;
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
        codCollected: attempt.codCollected,
      );
      if (completion.taskId != task.id ||
          completion.evidenceId != attempt.evidenceId ||
          !completion.isAwaitingValidation) {
        throw const ApiContractException('delivery.completion.intent');
      }
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
