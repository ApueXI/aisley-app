part of 'final_mile_batch_controller.dart';

extension FinalMileBatchControllerActions on FinalMileBatchController {
  Future<bool> accept(String scheduleId) async {
    final batch = batchById(scheduleId);
    if (batch == null || !batch.canAccept || isActionBusy(scheduleId)) {
      return false;
    }
    if (_uncertainAcceptances.contains(scheduleId)) {
      return _reconcileBeforeRetry(scheduleId);
    }
    return _submitAcceptance(scheduleId);
  }

  Future<bool> retryAcceptance(String scheduleId) async {
    if (isActionBusy(scheduleId)) return false;
    if (_uncertainAcceptances.contains(scheduleId)) {
      return _reconcileBeforeRetry(scheduleId);
    }
    return accept(scheduleId);
  }

  Future<bool> _submitAcceptance(String scheduleId) async {
    _actionStatuses[scheduleId] = FinalMileBatchActionStatus.accepting;
    _actionErrors[scheduleId] = null;
    _notify();
    try {
      final accepted = await repository.acceptBatch(scheduleId);
      _requireSameBatch(scheduleId, accepted);
      if (!accepted.isAccepted) {
        throw const ApiContractException('batch.accept.status');
      }
      return await _completeAcceptance(accepted);
    } on ApiException catch (error) {
      if (_isUncertain(error)) {
        _uncertainAcceptances.add(scheduleId);
        return await _reconcileAfterUncertain(scheduleId, error);
      }
      if (error.statusCode == 409 && error.code == 'BATCH_STATE_CONFLICT') {
        await _refreshAfterConflict(scheduleId);
      }
      _setActionError(scheduleId, error);
      await _handleAuthFailure(error);
    } on TokenStorageException {
      _actionStatuses[scheduleId] =
          FinalMileBatchActionStatus.secureStorageFailure;
      _actionErrors[scheduleId] =
          'Secure session storage is unavailable. The batch was not accepted.';
    } on ApiContractException {
      _actionStatuses[scheduleId] = FinalMileBatchActionStatus.failed;
      _actionErrors[scheduleId] =
          'The acceptance response did not match the documented API contract.';
    }
    _notify();
    return false;
  }

  Future<bool> _reconcileAfterUncertain(
    String scheduleId,
    ApiException original,
  ) async {
    _actionStatuses[scheduleId] = FinalMileBatchActionStatus.reconciling;
    _actionErrors[scheduleId] =
        'Checking the server before this acceptance can be retried.';
    _notify();
    try {
      final current = await repository.fetchBatch(scheduleId);
      _requireSameBatch(scheduleId, current);
      _upsert(current);
      if (current.isAccepted) return await _completeAcceptance(current);
      _setUncertainError(scheduleId, original);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        _setActionError(scheduleId, error);
      } else {
        _setUncertainError(scheduleId, original);
      }
      await _handleAuthFailure(error);
    } on TokenStorageException {
      _actionStatuses[scheduleId] =
          FinalMileBatchActionStatus.secureStorageFailure;
      _actionErrors[scheduleId] = 'The result could not be checked because secure storage is unavailable.';
    } on ApiContractException {
      _actionStatuses[scheduleId] = FinalMileBatchActionStatus.failed;
      _actionErrors[scheduleId] = 'The server result could not be reconciled safely. Refresh before retrying.';
    }
    _notify();
    return false;
  }

  Future<bool> _reconcileBeforeRetry(String scheduleId) async {
    _actionStatuses[scheduleId] = FinalMileBatchActionStatus.reconciling;
    _actionErrors[scheduleId] = 'Checking current batch state…';
    _notify();
    try {
      final current = await repository.fetchBatch(scheduleId);
      _requireSameBatch(scheduleId, current);
      _upsert(current);
      if (current.isAccepted) return await _completeAcceptance(current);
      if (!current.canAccept) {
        _actionStatuses[scheduleId] = FinalMileBatchActionStatus.conflict;
        _actionErrors[scheduleId] =
            'This batch is no longer available for acceptance.';
        _uncertainAcceptances.remove(scheduleId);
        _notify();
        return false;
      }
      _uncertainAcceptances.remove(scheduleId);
      return await _submitAcceptance(scheduleId);
    } on ApiException catch (error) {
      _setActionError(scheduleId, error);
      await _handleAuthFailure(error);
    } on TokenStorageException {
      _actionStatuses[scheduleId] =
          FinalMileBatchActionStatus.secureStorageFailure;
      _actionErrors[scheduleId] = 'Secure session storage is unavailable. Current state cannot be checked.';
    } on ApiContractException {
      _actionStatuses[scheduleId] = FinalMileBatchActionStatus.failed;
      _actionErrors[scheduleId] =
          'The batch could not be reconciled safely. Refresh before retrying.';
    }
    _notify();
    return false;
  }

  Future<void> _refreshAfterConflict(String scheduleId) async {
    try {
      final current = await repository.fetchBatch(scheduleId);
      _requireSameBatch(scheduleId, current);
      _upsert(current);
    } catch (_) {
      // The original conflict remains authoritative and visible.
    }
  }

  Future<bool> _completeAcceptance(FinalMileBatch accepted) async {
    _upsert(accepted);
    _uncertainAcceptances.remove(accepted.id);
    _actionStatuses[accepted.id] = FinalMileBatchActionStatus.accepted;
    _actionErrors[accepted.id] = null;
    _detailStatuses[accepted.id] = FinalMileBatchLoadStatus.loaded;
    _notify();
    try {
      await onBatchAccepted?.call();
    } catch (_) {
      // Acceptance stays successful even if a dependent refresh fails.
    }
    return true;
  }
}
