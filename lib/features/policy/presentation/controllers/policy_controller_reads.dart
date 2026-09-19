part of 'policy_controller.dart';

extension PolicyControllerReads on PolicyController {
  Future<bool> load({bool forceRefresh = false}) async {
    if (_statusRequestInFlight) {
      return false;
    }
    if (!forceRefresh && !isStatusStale && consentStatus != null) {
      return true;
    }

    final operationEpoch = ++_operationEpoch;
    _statusRequestInFlight = true;
    state = PolicyViewState.loadingStatus;
    errorMessage = null;
    successMessage = null;
    retryAfter = null;
    _notifyPolicyListeners();

    try {
      final status = await policyApi.fetchConsentStatus();
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      consentStatus = status;
      _statusLoadedAt = DateTime.now();
      state = PolicyViewState.loadingDocument;
      _notifyPolicyListeners();

      final supportedItems = status.supportedPolicies
          .where((item) => item.currentVersion != null)
          .toList(growable: false);
      final failures = <Object>[];
      final failedTypes = <PolicyType>{};
      final loadedDocuments = <PolicyType, PolicyDocument>{};
      await Future.wait(
        supportedItems.map((item) async {
          final type = item.type!;
          try {
            final document = await policyApi.fetchCurrent(
              type,
              forceRefresh: forceRefresh,
            );
            if (operationEpoch == _operationEpoch) {
              loadedDocuments[type] = document;
            }
          } on Object catch (error) {
            failures.add(error);
            failedTypes.add(type);
          }
        }),
      );
      if (operationEpoch != _operationEpoch) {
        return false;
      }

      final currentTypes = loadedDocuments.keys.toSet();
      documents.removeWhere(
        (type, _) =>
            supportedItems.every((item) => item.type != type) ||
            status.itemFor(type)?.currentVersion == null,
      );
      documents.addAll(loadedDocuments);
      staleDocuments.removeWhere(
        (type) =>
            !documents.containsKey(type) ||
            supportedItems.every((item) => item.type != type),
      );
      for (final item in supportedItems) {
        final type = item.type!;
        final document = documents[type];
        if (document == null) {
          continue;
        }
        if (failedTypes.contains(type) ||
            document.version.version != item.currentVersion) {
          staleDocuments.add(type);
        } else if (currentTypes.contains(type)) {
          staleDocuments.remove(type);
        }
      }

      if (failures.isNotEmpty) {
        await _setFailure(failures.first);
        return false;
      }

      state = _contentState();
      return true;
    } on Object catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      await _setFailure(error);
      return false;
    } finally {
      if (operationEpoch == _operationEpoch) {
        _statusRequestInFlight = false;
        _notifyPolicyListeners();
      }
    }
  }

  Future<bool> refreshIfStale() {
    return isStatusStale ? load(forceRefresh: true) : Future<bool>.value(true);
  }

  Future<bool> retry() {
    if (state == PolicyViewState.signedOut ||
        state == PolicyViewState.unauthorized ||
        state == PolicyViewState.forbidden) {
      return Future<bool>.value(false);
    }
    if (state == PolicyViewState.rateLimited && !canRetryRateLimit) {
      return Future<bool>.value(false);
    }
    return load(forceRefresh: true);
  }
}
