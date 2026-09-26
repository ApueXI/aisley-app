part of 'final_mile_batch_controller.dart';

extension FinalMileBatchControllerReads on FinalMileBatchController {
  Future<void> load() async {
    if (_listInFlight || !canRetryRateLimit) return;
    final epoch = ++_epoch;
    _listInFlight = true;
    _authFailureNotified = false;
    listStatus = FinalMileBatchLoadStatus.loading;
    listError = null;
    _notify();
    try {
      final loaded = await repository.fetchBatches();
      if (epoch != _epoch) return;
      batches = List<FinalMileBatch>.unmodifiable(loaded);
      for (final batch in loaded) {
        _details[batch.id] = batch;
      }
      listStatus = loaded.isEmpty
          ? FinalMileBatchLoadStatus.empty
          : FinalMileBatchLoadStatus.loaded;
      listError = null;
    } on ApiException catch (error) {
      if (epoch != _epoch) return;
      listStatus = _loadStatusFor(error);
      listError = _messageFor(error, noun: 'dispatch batches');
      _handleRateLimit(error);
      await _handleAuthFailure(error);
    } on TokenStorageException {
      if (epoch != _epoch) return;
      listStatus = FinalMileBatchLoadStatus.secureStorageFailure;
      listError = 'Secure session storage is unavailable. Batch offers cannot be loaded.';
    } on ApiContractException {
      if (epoch != _epoch) return;
      listStatus = FinalMileBatchLoadStatus.failed;
      listError = 'The batch service returned an unexpected response.';
    } finally {
      if (epoch == _epoch) {
        _listInFlight = false;
        _notify();
      }
    }
  }

  Future<void> loadDetail(String scheduleId) async {
    if (detailStatus(scheduleId) == FinalMileBatchLoadStatus.loading ||
        !canRetryRateLimit) {
      return;
    }
    _detailStatuses[scheduleId] = FinalMileBatchLoadStatus.loading;
    _detailErrors[scheduleId] = null;
    _notify();
    try {
      final batch = await repository.fetchBatch(scheduleId);
      _requireSameBatch(scheduleId, batch);
      _upsert(batch);
      _detailStatuses[scheduleId] = FinalMileBatchLoadStatus.loaded;
      final action = actionStatus(scheduleId);
      if (batch.isAccepted) {
        _uncertainAcceptances.remove(scheduleId);
        _actionStatuses[scheduleId] = FinalMileBatchActionStatus.accepted;
        _actionErrors[scheduleId] = null;
      } else if (action == FinalMileBatchActionStatus.conflict ||
          action == FinalMileBatchActionStatus.unavailable ||
          action == FinalMileBatchActionStatus.validationError ||
          action == FinalMileBatchActionStatus.consentRequired) {
        _actionStatuses[scheduleId] = FinalMileBatchActionStatus.idle;
        _actionErrors[scheduleId] = null;
      }
    } on ApiException catch (error) {
      _detailStatuses[scheduleId] = _loadStatusFor(error);
      _detailErrors[scheduleId] = _messageFor(error, noun: 'dispatch batch');
      _handleRateLimit(error);
      await _handleAuthFailure(error);
    } on TokenStorageException {
      _detailStatuses[scheduleId] =
          FinalMileBatchLoadStatus.secureStorageFailure;
      _detailErrors[scheduleId] = 'Secure session storage is unavailable. Batch details cannot be loaded.';
    } on ApiContractException {
      _detailStatuses[scheduleId] = FinalMileBatchLoadStatus.failed;
      _detailErrors[scheduleId] =
          'The batch details did not match the documented API response.';
    }
    _notify();
  }
}
