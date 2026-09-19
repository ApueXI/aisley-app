part of 'policy_controller.dart';

extension PolicyControllerErrors on PolicyController {
  PolicyViewState _contentState() {
    final status = consentStatus;
    if (status == null) {
      return PolicyViewState.retryableError;
    }
    return status.supportedPolicies.any(
          (item) => item.required && !item.accepted,
        )
        ? PolicyViewState.consentRequired
        : PolicyViewState.ready;
  }

  Future<bool> _refreshAsStale() async {
    final refreshed = await load(forceRefresh: true);
    if (refreshed) {
      return _setStaleState();
    }
    return false;
  }

  Future<bool> _setStaleState() async {
    state = PolicyViewState.staleVersion;
    errorMessage = 'This policy changed before it could be accepted. Review the current version and confirm it again.';
    successMessage = null;
    _notifyPolicyListeners();
    return false;
  }

  Future<bool> _reconcileUnknownAcceptance(
    PolicyType type,
    int version,
    ApiException originalError,
  ) async {
    final refreshed = await load(forceRefresh: true);
    final item = consentFor(type);
    if (refreshed &&
        item?.accepted == true &&
        item?.acceptedVersion == version) {
      state = PolicyViewState.accepted;
      successMessage = '${item!.label} version $version was accepted.';
      errorMessage = null;
      _notifyPolicyListeners();
      return true;
    }

    if (state != PolicyViewState.unauthorized &&
        state != PolicyViewState.forbidden) {
      await _setFailure(originalError);
      errorMessage = 'The acceptance result is unknown. We refreshed your consent status; retry only after reviewing it.';
      _notifyPolicyListeners();
    }
    return false;
  }

  Future<void> _setFailure(Object error) async {
    if (error is ApiException) {
      await _setApiFailure(error);
      return;
    }
    if (error is ApiContractException) {
      state = PolicyViewState.retryableError;
      errorMessage = _contractFailureMessage(error);
      successMessage = null;
      _notifyPolicyListeners();
      return;
    }
    if (error is TokenStorageException) {
      state = PolicyViewState.retryableError;
      errorMessage = 'Secure session storage is unavailable. Unlock your keyring and retry.';
      successMessage = null;
      _notifyPolicyListeners();
      return;
    }
    state = PolicyViewState.retryableError;
    errorMessage = 'We could not load policy information. Please retry.';
    successMessage = null;
    _notifyPolicyListeners();
  }

  String _contractFailureMessage(ApiContractException error) {
    return switch (error.field) {
      'policy.consent.response' => 'The policy status response was empty or invalid. Confirm the API returns JSON, then retry.',
      'policy.consent.data' => 'The policy status response is missing its policy data object. Confirm the API response envelope, then retry.',
      'policy.consent.item' ||
      'policy.consent.type' ||
      'policy.consent.label' ||
      'policy.consent.flags' ||
      'policy.consent.accepted_at' ||
      'policy.consent.current_version' ||
      'policy.consent.accepted_version' =>
        'The policy status fields do not match the documented API contract (${error.field}). Update the API response or client contract, then retry.',
      _ =>
        'The policy service returned an unexpected response (${error.field}). Confirm the documented API contract, then retry.',
    };
  }

  Future<void> _setApiFailure(ApiException error) async {
    retryAfter = error.retryAfter;
    successMessage = null;

    if (error.statusCode == 401) {
      state = PolicyViewState.unauthorized;
      errorMessage = 'Your session is no longer valid. Please sign in again.';
      consentStatus = null;
      lastAcceptance = null;
      await onAuthFailure?.call(error);
      _notifyPolicyListeners();
      return;
    }
    if (error.statusCode == 403) {
      state = PolicyViewState.forbidden;
      errorMessage = error.message.isEmpty
          ? 'Your account is not currently eligible for policy consent.'
          : error.message;
      _notifyPolicyListeners();
      return;
    }
    if (error.statusCode == 422) {
      state = PolicyViewState.validationError;
      errorMessage = 'Confirm the policy checkbox before trying again.';
      _notifyPolicyListeners();
      return;
    }
    if (error.statusCode == 429) {
      state = PolicyViewState.rateLimited;
      final duration = error.retryAfter ?? const Duration(seconds: 1);
      _rateLimitTimer?.cancel();
      _rateLimitTimer = Timer(duration, () {
        _rateLimitTimer = null;
        retryAfter = null;
        _notifyPolicyListeners();
      });
      errorMessage = duration.inSeconds <= 1
          ? 'Too many attempts. Try again in a moment.'
          : 'Too many attempts. Try again in ${duration.inSeconds} seconds.';
      _notifyPolicyListeners();
      return;
    }
    if (error.isNetworkError) {
      state = error.networkFailure == ApiNetworkFailure.timeout
          ? PolicyViewState.timeout
          : PolicyViewState.offline;
      errorMessage = error.networkFailure == ApiNetworkFailure.timeout
          ? 'The policy request timed out. Check your connection and retry.'
          : 'The policy service is unavailable offline. Reconnect and retry.';
      _notifyPolicyListeners();
      return;
    }
    state = PolicyViewState.retryableError;
    if (error.statusCode == 404) {
      errorMessage = 'The policy consent endpoint is unavailable on this API. Deploy the policy routes and retry.';
    } else if (error.statusCode != null && error.statusCode! >= 500) {
      errorMessage = 'The policy service returned a server error. Check the policy migrations and seed data, then retry.';
    } else {
      errorMessage = 'We could not load policy information. Please retry.';
    }
    _notifyPolicyListeners();
  }

  String _messageForError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 404) {
        return 'This policy version is no longer available.';
      }
      if (error.statusCode == 403) {
        return error.message;
      }
      if (error.isNetworkError) {
        return error.networkFailure == ApiNetworkFailure.timeout
            ? 'The policy request timed out. Retry when connected.'
            : 'The policy could not be loaded offline. Retry when connected.';
      }
    }
    return 'We could not load this policy information. Please retry.';
  }
}
