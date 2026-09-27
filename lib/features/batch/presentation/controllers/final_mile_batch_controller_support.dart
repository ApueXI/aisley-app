part of 'final_mile_batch_controller.dart';

extension FinalMileBatchControllerSupport on FinalMileBatchController {
  void _setActionError(String scheduleId, ApiException error) {
    _actionStatuses[scheduleId] = _actionStatusFor(error);
    _actionErrors[scheduleId] = _messageFor(error, noun: 'dispatch batch');
    if (error.statusCode == 404) {
      _detailStatuses[scheduleId] = FinalMileBatchLoadStatus.unavailable;
      _detailErrors[scheduleId] = _actionErrors[scheduleId];
    }
    _handleRateLimit(error);
  }

  void _setUncertainError(String scheduleId, ApiException original) {
    _actionStatuses[scheduleId] =
        original.networkFailure == ApiNetworkFailure.timeout
        ? FinalMileBatchActionStatus.timeout
        : original.isNetworkError
        ? FinalMileBatchActionStatus.offline
        : FinalMileBatchActionStatus.failed;
    _actionErrors[scheduleId] = 'The acceptance result is not confirmed. Retry will check current server state before resending.';
  }

  void _upsert(FinalMileBatch batch) {
    _details[batch.id] = batch;
    final index = batches.indexWhere((item) => item.id == batch.id);
    if (index < 0) return;
    final updated = List<FinalMileBatch>.of(batches)..[index] = batch;
    batches = List<FinalMileBatch>.unmodifiable(updated);
  }

  void _requireSameBatch(String requestedId, FinalMileBatch batch) {
    if (batch.id != requestedId) {
      throw const ApiContractException('batch.response.id');
    }
  }

  bool _isUncertain(ApiException error) =>
      error.isNetworkError ||
      (error.statusCode != null && error.statusCode! >= 500);

  FinalMileBatchLoadStatus _loadStatusFor(ApiException error) {
    if (error.statusCode == 401) {
      return FinalMileBatchLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? FinalMileBatchLoadStatus.consentRequired
          : FinalMileBatchLoadStatus.forbidden;
    }
    if (error.statusCode == 404) {
      return FinalMileBatchLoadStatus.unavailable;
    }
    if (error.statusCode == 429) {
      return FinalMileBatchLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? FinalMileBatchLoadStatus.timeout
          : FinalMileBatchLoadStatus.offline;
    }
    return FinalMileBatchLoadStatus.failed;
  }

  FinalMileBatchActionStatus _actionStatusFor(ApiException error) {
    if (error.statusCode == 401) {
      return FinalMileBatchActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? FinalMileBatchActionStatus.consentRequired
          : FinalMileBatchActionStatus.forbidden;
    }
    if (error.statusCode == 404) {
      return FinalMileBatchActionStatus.unavailable;
    }
    if (error.statusCode == 409) {
      return FinalMileBatchActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return FinalMileBatchActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return FinalMileBatchActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? FinalMileBatchActionStatus.timeout
          : FinalMileBatchActionStatus.offline;
    }
    return FinalMileBatchActionStatus.failed;
  }

  String _messageFor(ApiException error, {required String noun}) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current policies before reviewing or accepting $noun.';
    }
    if (error.statusCode == 404 && error.code == 'BATCH_NOT_FOUND') {
      return 'This dispatch batch is no longer available. Return to the list and refresh.';
    }
    if (error.statusCode == 409 && error.code == 'BATCH_STATE_CONFLICT') {
      return 'A parcel in this batch changed on the server. Review the refreshed batch before continuing.';
    }
    if (error.statusCode == 422) {
      return error.message.isEmpty
          ? 'The request was not valid.'
          : error.message;
    }
    if (error.statusCode == 429) {
      return 'Too many requests. Wait before trying again.';
    }
    if (error.statusCode == 401) return 'Your Courier session has expired.';
    if (error.statusCode == 403) {
      return 'This $noun is not available to your Courier account.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'The request timed out. Try again when the connection improves.'
          : 'The service is unreachable. Reconnect and try again.';
    }
    return 'The $noun could not be loaded. Please retry.';
  }

  void _handleRateLimit(ApiException error) {
    if (error.statusCode != 429) return;
    final delay = error.retryAfter ?? const Duration(seconds: 1);
    _retryTimer?.cancel();
    retryAfter = delay;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      retryAfter = null;
      _notify();
    });
  }

  Future<void> _handleAuthFailure(ApiException error) async {
    if (error.statusCode != 401 || _authFailureNotified) return;
    _authFailureNotified = true;
    await onAuthFailure?.call(error);
  }
}
