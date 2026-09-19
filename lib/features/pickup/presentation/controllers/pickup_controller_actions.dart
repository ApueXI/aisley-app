part of 'pickup_controller.dart';

extension PickupControllerActions on PickupController {
  Future<bool> acceptTask(PickupTask task) async {
    if (!task.isAssigned || isActionBusy(task)) {
      return false;
    }

    final key = PickupController._taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.accepting;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();

    try {
      final accepted = task.isFirstMile
          ? await pickupRepository.acceptFirstMileTask(task.id)
          : await pickupRepository.acceptFinalMileTask(task.id);
      _replaceTask(accepted);
      _actionStatuses[key] = PickupTaskActionStatus.accepted;
      _notifyPickupListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<WaybillResolution?> resolveWaybill(String payload) async {
    waybillResolutionError = null;
    lastWaybillResolution = null;
    waybillResolutionStatus = null;
    try {
      final resolution = await pickupRepository.resolveWaybill(payload);
      lastWaybillResolution = resolution;
      waybillResolutionStatus = PickupSectionStatus.loaded;
      _notifyPickupListeners();
      return resolution;
    } on ApiException catch (error) {
      waybillResolutionError = _messageForError(error);
      waybillResolutionStatus = _sectionStateFor(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      _notifyPickupListeners();
      if (error.statusCode == 401) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      waybillResolutionStatus = PickupSectionStatus.secureStorageFailure;
      waybillResolutionError =
          'Secure session storage is unavailable. The QR could not be checked.';
      _notifyPickupListeners();
    } on ApiContractException {
      waybillResolutionStatus = PickupSectionStatus.failed;
      waybillResolutionError = 'The QR response was not understood. Enter the Order reference instead.';
      _notifyPickupListeners();
    }
    return null;
  }

  Future<bool> rejectFinalMileTask(
    PickupTask task, {
    required String reason,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.deliveryAssigned ||
        isActionBusy(task)) {
      return false;
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.length < 3 || normalizedReason.length > 1000) {
      _setLocalValidationError(
        task,
        'Enter a rejection reason between 3 and 1,000 characters.',
      );
      return false;
    }

    final key = PickupController._taskKey(task);
    final pending = _pendingRejections[key];
    final attempt = pending != null && pending.reason == normalizedReason
        ? pending
        : _PendingRejectionAttempt(
            reason: normalizedReason,
            idempotencyKey: PickupController._newUuid(),
          );
    _pendingRejections[key] = attempt;
    return _performFinalMileRejection(task, attempt);
  }

  Future<bool> retryFinalMileRejection(PickupTask task) async {
    final attempt = _pendingRejections[PickupController._taskKey(task)];
    if (attempt == null || !task.isFinalMile) {
      return false;
    }
    return _performFinalMileRejection(task, attempt);
  }

  Future<bool> _performFinalMileRejection(
    PickupTask task,
    _PendingRejectionAttempt attempt,
  ) async {
    final key = PickupController._taskKey(task);
    if (isActionBusy(task)) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.rejecting;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();

    try {
      final result = await pickupRepository.rejectFinalMileTask(
        taskId: task.id,
        reason: attempt.reason,
        idempotencyKey: attempt.idempotencyKey,
      );
      _pendingRejections.remove(key);
      _replaceTask(
        task.copyWith(
          rawStatus: result.status,
          rejectionReason: result.rejectionReason ?? attempt.reason,
          offerRespondedAt: result.respondedAt,
        ),
      );
      _actionStatuses[key] = PickupTaskActionStatus.rejected;
      _notifyPickupListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<bool> confirmFirstMilePickup(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) async {
    if (!task.isFirstMile || !task.isAccepted || isActionBusy(task)) {
      return false;
    }

    final normalizedIdentifier = identifier.trim();
    if (!PickupController._validIdentifier(
      identifierType,
      normalizedIdentifier,
    )) {
      _setLocalValidationError(
        task,
        'Choose QR or Order ID/reference and enter a value up to 128 characters.',
      );
      return false;
    }

    final pending = _pendingAttempt(
      task,
      identifierType: identifierType,
      identifier: normalizedIdentifier,
    );
    return _performFirstMilePickup(task, pending);
  }

  Future<bool> retryFirstMilePickup(PickupTask task) async {
    final pending = _pendingAttempts[PickupController._taskKey(task)];
    if (pending == null || pending.leg != PickupTaskLeg.firstMile) {
      return false;
    }
    return _performFirstMilePickup(task, pending);
  }

  Future<bool> _performFirstMilePickup(
    PickupTask task,
    _PendingPickupAttempt pending,
  ) async {
    final key = PickupController._taskKey(task);
    if (isActionBusy(task)) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.confirming;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();

    try {
      final result = await pickupRepository.confirmFirstMilePickup(
        taskId: task.id,
        identifierType: pending.identifierType,
        identifier: pending.identifier,
        idempotencyKey: pending.idempotencyKey,
      );
      lastFirstMilePickup = result;
      _pendingAttempts.remove(key);
      _replaceTask(
        task.copyWith(
          rawStatus: result.taskStatus,
          pickedUpAt: result.pickedUpAt,
        ),
      );
      _actionStatuses[key] = PickupTaskActionStatus.succeeded;
      _notifyPickupListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<bool> submitFinalMilePickup(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.deliveryAccepted ||
        task.revision == null ||
        isActionBusy(task)) {
      return false;
    }

    final normalizedIdentifier = identifier.trim();
    if (!PickupController._validIdentifier(
      identifierType,
      normalizedIdentifier,
    )) {
      _setLocalValidationError(
        task,
        'Choose QR or Order ID/reference and enter a value up to 128 characters.',
      );
      return false;
    }

    final pending = _pendingAttempt(
      task,
      identifierType: identifierType,
      identifier: normalizedIdentifier,
    );
    return _performFinalMilePickup(task, pending);
  }

  Future<bool> retryFinalMilePickup(PickupTask task) async {
    final pending = _pendingAttempts[PickupController._taskKey(task)];
    if (pending == null || pending.leg != PickupTaskLeg.finalMile) {
      return false;
    }
    return _performFinalMilePickup(task, pending);
  }

  Future<bool> _performFinalMilePickup(
    PickupTask task,
    _PendingPickupAttempt pending,
  ) async {
    final key = PickupController._taskKey(task);
    if (isActionBusy(task) || task.revision == null) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.confirming;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();

    try {
      final result = await pickupRepository.submitFinalMilePickup(
        taskId: task.id,
        identifierType: pending.identifierType,
        identifier: pending.identifier,
        expectedRevision: task.revision!,
        idempotencyKey: pending.idempotencyKey,
      );
      lastFinalMilePickup = result;
      _pendingAttempts.remove(key);
      _actionStatuses[key] = PickupTaskActionStatus.awaitingValidation;
      _notifyPickupListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }
}
