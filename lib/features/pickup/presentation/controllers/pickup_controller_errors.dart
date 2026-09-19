part of 'pickup_controller.dart';

extension PickupControllerErrors on PickupController {
  Future<void> _setSectionError({
    required bool firstMile,
    required ApiException error,
    required int epoch,
  }) async {
    if (epoch != _loadEpoch) {
      return;
    }

    final state = _sectionStateFor(error);
    final message = _messageForError(error);
    if (firstMile) {
      firstMileStatus = state;
      firstMileErrorMessage = message;
    } else {
      finalMileStatus = state;
      finalMileErrorMessage = message;
    }
    if (state == PickupSectionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyPickupListeners();

    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setActionError(PickupTask task, ApiException error) async {
    final key = PickupController._taskKey(task);
    final state = _actionStateFor(error);
    _actionStatuses[key] = state;
    _actionErrors[key] = _messageForError(error);
    _actionRetryAfter[key] = error.retryAfter;
    if (state == PickupTaskActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyPickupListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  void _setLocalValidationError(PickupTask task, String message) {
    final key = PickupController._taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.validationError;
    _actionErrors[key] = message;
    _actionRetryAfter[key] = null;
    _notifyPickupListeners();
  }

  void _setActionStorageError(PickupTask task) {
    final key = PickupController._taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.secureStorageFailure;
    _actionErrors[key] =
        'Secure session storage is unavailable. The action was not submitted.';
    _notifyPickupListeners();
  }

  void _setActionContractError(PickupTask task) {
    final key = PickupController._taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.failed;
    _actionErrors[key] =
        'The pickup service returned an unexpected response. Please retry.';
    _notifyPickupListeners();
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
      _notifyPickupListeners();
    });
    retryAfter = delay;
  }

  PickupSectionStatus _sectionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return PickupSectionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? PickupSectionStatus.consentRequired
          : PickupSectionStatus.forbidden;
    }
    if (error.statusCode == 429) {
      return PickupSectionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? PickupSectionStatus.timeout
          : PickupSectionStatus.offline;
    }
    return PickupSectionStatus.failed;
  }

  PickupTaskActionStatus _actionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return PickupTaskActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? PickupTaskActionStatus.consentRequired
          : PickupTaskActionStatus.forbidden;
    }
    if (error.statusCode == 409) {
      return PickupTaskActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return PickupTaskActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return PickupTaskActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? PickupTaskActionStatus.timeout
          : PickupTaskActionStatus.offline;
    }
    return PickupTaskActionStatus.failed;
  }

  String _messageForError(ApiException error) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current Terms of Service and Privacy Policy before pickup actions are available.';
    }
    if (error.statusCode == 404) {
      return 'This pickup is no longer available. Refresh to see the current work assigned to you.';
    }
    if (error.statusCode == 409) {
      return 'This pickup changed on the server. Refresh before trying again.';
    }
    if (error.statusCode == 422) {
      return error.message.isEmpty
          ? 'Check the identifier and try again.'
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
          ? 'This pickup is not available to your Courier account.'
          : error.message;
    }
    return 'The pickup service could not complete the request. Please retry.';
  }
}
