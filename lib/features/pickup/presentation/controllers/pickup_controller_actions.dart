part of 'pickup_controller.dart';

extension PickupControllerActions on PickupController {
  Future<bool> acceptTask(PickupTask task) async {
    if (!task.isFirstMile || !task.isAssigned || isActionBusy(task)) {
      return false;
    }

    final key = PickupController._taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.accepting;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();

    try {
      final accepted = await pickupRepository.acceptFirstMileTask(task.id);
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
        'Choose QR, tracking ID, or Order ID/reference and enter a value up to 128 characters.',
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

  Future<bool> submitFinalMilePickup(PickupTask task) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.deliveryAccepted ||
        isActionBusy(task) ||
        (actionStatus(task) == PickupTaskActionStatus.awaitingValidation &&
            hubPickupSubmissions.containsKey(task.id))) {
      return false;
    }
    final key = PickupController._taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.confirming;
    _actionErrors[key] = null;
    _notifyPickupListeners();
    try {
      final current = await pickupRepository.fetchFinalMileTask(task.id);
      if (current.id != task.id || !current.isFinalMile) {
        throw const ApiContractException('pickup.final_mile.task_identity');
      }
      _replaceTask(current);
      if (current.status != PickupTaskStatus.deliveryAccepted ||
          current.revision == null) {
        _actionStatuses[key] = PickupTaskActionStatus.conflict;
        _actionErrors[key] =
            'This hub handoff changed. Refresh the task before trying again.';
        _notifyPickupListeners();
        return false;
      }
      final pending = _PendingHubPickupAttempt(
        expectedRevision: current.revision!,
        idempotencyKey: PickupController._newUuid(),
      );
      _pendingHubPickups[key] = pending;
      return await _performFinalMilePickup(current, pending);
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<bool> retryFinalMilePickup(PickupTask task) async {
    final pending = _pendingHubPickups[PickupController._taskKey(task)];
    if (pending == null || !task.isFinalMile) {
      return false;
    }
    return _performFinalMilePickup(task, pending);
  }

  Future<bool> _performFinalMilePickup(
    PickupTask task,
    _PendingHubPickupAttempt pending,
  ) async {
    final key = PickupController._taskKey(task);
    if (task.status != PickupTaskStatus.deliveryAccepted ||
        (isActionBusy(task) &&
            _actionStatuses[key] != PickupTaskActionStatus.confirming)) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.confirming;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();

    try {
      final result = await pickupRepository.submitFinalMilePickup(
        taskId: task.id,
        expectedRevision: pending.expectedRevision,
        idempotencyKey: pending.idempotencyKey,
      );
      if (result.taskId != task.id) {
        throw const ApiContractException('pickup.final_mile.response.task_id');
      }
      lastFinalMilePickup = result;
      hubPickupSubmissions[task.id] = result;
      _pendingHubPickups.remove(key);
      _actionStatuses[key] = PickupTaskActionStatus.awaitingValidation;
      _notifyPickupListeners();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404 ||
          error.statusCode == 409 ||
          error.statusCode == 422) {
        _pendingHubPickups.remove(key);
      }
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }
}
