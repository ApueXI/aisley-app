part of 'policy_controller.dart';

extension PolicyControllerAcceptance on PolicyController {
  Future<bool> accept(PolicyType type) async {
    if (state == PolicyViewState.accepting) {
      return false;
    }
    final item = consentFor(type);
    final document = documentFor(type);
    final expectedVersion = item?.currentVersion;
    if (item == null || !item.required || expectedVersion == null) {
      state = PolicyViewState.validationError;
      errorMessage = 'This policy is not currently available for acceptance.';
      successMessage = null;
      _notifyPolicyListeners();
      return false;
    }
    if (document == null || document.version.version != expectedVersion) {
      return _refreshAsStale();
    }

    final originalVersion = expectedVersion;
    final loaded = await load(forceRefresh: true);
    if (!loaded) {
      return false;
    }

    final refreshedItem = consentFor(type);
    final refreshedDocument = documentFor(type);
    if (refreshedItem?.currentVersion != originalVersion ||
        refreshedDocument?.version.version != originalVersion) {
      return _setStaleState();
    }

    state = PolicyViewState.accepting;
    errorMessage = null;
    successMessage = null;
    retryAfter = null;
    _notifyPolicyListeners();

    try {
      final acceptance = await policyApi.accept(
        type: type,
        version: originalVersion,
      );
      if (acceptance.type != type ||
          acceptance.version.version != originalVersion) {
        throw const ApiContractException('policy.acceptance.version');
      }
      lastAcceptance = acceptance;
      final refreshed = await load(forceRefresh: true);
      final message =
          '${acceptance.label} version ${acceptance.version.version} was accepted.';
      if (refreshed) {
        state = PolicyViewState.accepted;
        successMessage = message;
        errorMessage = null;
        _notifyPolicyListeners();
      } else if (state != PolicyViewState.unauthorized &&
          state != PolicyViewState.forbidden) {
        state = PolicyViewState.accepted;
        successMessage = message;
        errorMessage =
            'Acceptance was committed, but status refresh is unavailable.';
        _notifyPolicyListeners();
      }
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 409 && error.code == 'POLICY_VERSION_STALE') {
        return _refreshAsStale();
      }
      if (error.isNetworkError) {
        return _reconcileUnknownAcceptance(type, originalVersion, error);
      }
      await _setFailure(error);
    } on Object catch (error) {
      await _setFailure(error);
    }
    return false;
  }
}
