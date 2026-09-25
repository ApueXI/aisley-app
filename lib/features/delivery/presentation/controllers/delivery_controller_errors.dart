part of 'delivery_controller.dart';

extension DeliveryControllerErrors on DeliveryController {
  Future<void> _setLoadError(ApiException error, int epoch) async {
    if (epoch != _loadEpoch) {
      return;
    }
    loadStatus = _loadStateFor(error);
    errorMessage = _messageForError(error);
    if (loadStatus == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setContextError(String taskId, ApiException error) async {
    contextStatuses[taskId] = _loadStateFor(error);
    contextErrors[taskId] = _messageForError(error);
    if (contextStatuses[taskId] == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setCompletionError(String taskId, ApiException error) async {
    completionStatuses[taskId] = _loadStateFor(error);
    completionErrors[taskId] = _messageForError(error);
    if (completionStatuses[taskId] == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setActionError(PickupTask task, ApiException error) async {
    _actionStatuses[task.id] = _actionStateFor(error);
    _actionErrors[task.id] = _messageForError(error);
    _actionRetryAfter[task.id] = error.retryAfter;
    if (_actionStatuses[task.id] == DeliveryActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  void _setLocalValidationError(PickupTask task, String message) {
    _actionStatuses[task.id] = DeliveryActionStatus.validationError;
    _actionErrors[task.id] = message;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();
  }

  void _setStorageActionError(PickupTask task) {
    _actionStatuses[task.id] = DeliveryActionStatus.secureStorageFailure;
    _actionErrors[task.id] =
        'Secure session storage is unavailable. The action was not submitted.';
    _notifyDeliveryListeners();
  }

  void _setContractActionError(PickupTask task, ApiContractException error) {
    _actionStatuses[task.id] = DeliveryActionStatus.failed;
    _actionErrors[task.id] = _contractFailureMessage(error);
    _notifyDeliveryListeners();
  }

  String _contractFailureMessage(ApiContractException error) {
    final field = error.field == 'delivery.completion.completion_status'
        ? 'data.completion_status'
        : error.field;
    return 'The delivery response does not match the documented API contract ($field). Please retry.';
  }

  Future<void> _notifyAuthFailure(ApiException error) async {
    if (_authFailureNotified) {
      return;
    }
    _authFailureNotified = true;
    await onAuthFailure?.call(error);
  }

  void _startRetryDelay(Duration? delay) {
    _retryTimer?.cancel();
    if (delay == null || delay <= Duration.zero) {
      _retryTimer = null;
      return;
    }
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      retryAfter = null;
      _notifyDeliveryListeners();
    });
    retryAfter = delay;
  }

  DeliveryLoadStatus _loadStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return DeliveryLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? DeliveryLoadStatus.consentRequired
          : DeliveryLoadStatus.forbidden;
    }
    if (error.statusCode == 429) {
      return DeliveryLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? DeliveryLoadStatus.timeout
          : DeliveryLoadStatus.offline;
    }
    return DeliveryLoadStatus.failed;
  }

  DeliveryActionStatus _actionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return DeliveryActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? DeliveryActionStatus.consentRequired
          : DeliveryActionStatus.forbidden;
    }
    if (error.statusCode == 409) {
      return DeliveryActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return DeliveryActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return DeliveryActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? DeliveryActionStatus.timeout
          : DeliveryActionStatus.offline;
    }
    return DeliveryActionStatus.failed;
  }

  String _messageForError(ApiException error) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current Terms of Service and Privacy Policy before delivery actions are available.';
    }
    if (error.code == 'PARCEL_NOT_FOUND') {
      return 'The parcel for this delivery task was not found. Refresh the task before trying again.';
    }
    if (error.code == 'TASK_STATE_CONFLICT') {
      return 'The task state or revision changed. Refresh the task before trying again.';
    }
    if (error.code == 'COMPLETION_STATE_CONFLICT') {
      return 'The completion state changed. Refresh the task before trying again.';
    }
    if (error.code == 'COD_COLLECTION_REQUIRED') {
      return 'Confirm the full Order payable total was collected before submitting Delivered intent.';
    }
    if (error.statusCode == 404) {
      return 'This delivery is no longer available. Refresh to see current work.';
    }
    if (error.statusCode == 409) {
      if (error.code == 'PROOF_NOT_VALIDATED') {
        return 'Logistics has not validated the proof yet. Refresh before trying completion again.';
      }
      return 'This delivery changed on the server. Refresh before trying again.';
    }
    if (error.statusCode == 422) {
      return error.message.isEmpty
          ? 'Check the submitted delivery information and try again.'
          : error.message;
    }
    if (error.statusCode == 429) {
      return 'Too many requests. Wait before trying again.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'The request timed out. Keep the same attempt and retry.'
          : 'The service is unreachable. Reconnect and retry.';
    }
    if (error.statusCode == 401) {
      return 'Your Courier session is no longer valid.';
    }
    if (error.statusCode == 403) {
      return error.message.isEmpty
          ? 'This delivery is not available to your Courier account.'
          : error.message;
    }
    return 'The delivery service could not complete the request. Please retry.';
  }
}
