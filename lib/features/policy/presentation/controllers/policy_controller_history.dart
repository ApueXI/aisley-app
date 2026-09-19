part of 'policy_controller.dart';

extension PolicyControllerHistory on PolicyController {
  Future<bool> loadHistory(PolicyType type, {bool forceRefresh = false}) async {
    if (isHistoryLoading(type)) {
      return false;
    }
    final operationEpoch = ++_historyEpoch;
    _historyLoading.add(type);
    historyErrors.remove(type);
    state = PolicyViewState.historyLoading;
    errorMessage = null;
    retryAfter = null;
    _notifyPolicyListeners();

    try {
      final history = await policyApi.fetchHistory(
        type,
        forceRefresh: forceRefresh,
      );
      if (operationEpoch != _historyEpoch) {
        return false;
      }
      histories[type] = history;
      state = _contentState();
      return true;
    } on Object catch (error) {
      if (operationEpoch != _historyEpoch) {
        return false;
      }
      historyErrors[type] = _messageForError(error);
      await _setFailure(error);
      return false;
    } finally {
      _historyLoading.remove(type);
      if (operationEpoch == _historyEpoch) {
        _notifyPolicyListeners();
      }
    }
  }

  Future<PolicyDocument?> loadHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  }) async {
    final key = _historyKey(type, version);
    if (_historyVersionLoading.contains(key)) {
      return null;
    }
    final operationEpoch = ++_historyEpoch;
    _historyVersionLoading.add(key);
    errorMessage = null;
    retryAfter = null;
    state = PolicyViewState.loadingDocument;
    _notifyPolicyListeners();

    try {
      final document = await policyApi.fetchHistoryVersion(
        type,
        version,
        forceRefresh: forceRefresh,
      );
      if (operationEpoch != _historyEpoch) {
        return null;
      }
      historyDocuments[key] = document;
      state = _contentState();
      return document;
    } on Object catch (error) {
      if (operationEpoch != _historyEpoch) {
        return null;
      }
      errorMessage = _messageForError(error);
      await _setFailure(error);
      return null;
    } finally {
      _historyVersionLoading.remove(key);
      if (operationEpoch == _historyEpoch) {
        _notifyPolicyListeners();
      }
    }
  }
}
