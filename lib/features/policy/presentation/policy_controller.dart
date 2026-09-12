import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../data/policy_repository.dart';
import '../domain/policy_models.dart';

typedef PolicyAuthFailureHandler = Future<void> Function(ApiException error);

enum PolicyViewState {
  signedOut,
  loadingStatus,
  loadingDocument,
  ready,
  historyLoading,
  consentRequired,
  accepting,
  accepted,
  validationError,
  unauthorized,
  forbidden,
  staleVersion,
  rateLimited,
  timeout,
  offline,
  retryableError,
}

class PolicyController extends ChangeNotifier {
  PolicyController({required this.policyApi, this.onAuthFailure});

  static const statusTtl = Duration(minutes: 5);

  final PolicyApi policyApi;
  final PolicyAuthFailureHandler? onAuthFailure;
  final Map<PolicyType, PolicyDocument> documents = {};
  final Set<PolicyType> staleDocuments = <PolicyType>{};
  final Map<PolicyType, PolicyHistory> histories = {};
  final Map<String, PolicyDocument> historyDocuments = {};
  final Map<PolicyType, String> historyErrors = {};
  final Set<PolicyType> _historyLoading = <PolicyType>{};
  final Set<String> _historyVersionLoading = <String>{};
  int _operationEpoch = 0;
  int _historyEpoch = 0;
  bool _statusRequestInFlight = false;
  DateTime? _statusLoadedAt;
  Timer? _rateLimitTimer;

  PolicyViewState state = PolicyViewState.signedOut;
  PolicyConsentStatus? consentStatus;
  PolicyAcceptance? lastAcceptance;
  String? errorMessage;
  String? successMessage;
  Duration? retryAfter;

  bool get isBusy =>
      state == PolicyViewState.loadingStatus ||
      state == PolicyViewState.loadingDocument ||
      state == PolicyViewState.accepting;

  bool get canRetryRateLimit => _rateLimitTimer == null;

  bool get isStatusStale {
    final loadedAt = _statusLoadedAt;
    return loadedAt == null || DateTime.now().difference(loadedAt) >= statusTtl;
  }

  bool get hasUnsupportedRequiredPolicy =>
      consentStatus?.policies.any(
        (item) => item.required && !item.isSupported,
      ) ??
      false;

  PolicyConsentItem? consentFor(PolicyType type) {
    return consentStatus?.itemFor(type);
  }

  PolicyDocument? documentFor(PolicyType type) => documents[type];

  bool isDocumentStale(PolicyType type) => staleDocuments.contains(type);

  PolicyHistory? historyFor(PolicyType type) => histories[type];

  bool isHistoryLoading(PolicyType type) => _historyLoading.contains(type);

  bool isHistoryVersionLoading(PolicyType type, int version) {
    return _historyVersionLoading.contains(_historyKey(type, version));
  }

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
    notifyListeners();

    try {
      final status = await policyApi.fetchConsentStatus();
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      consentStatus = status;
      _statusLoadedAt = DateTime.now();
      state = PolicyViewState.loadingDocument;
      notifyListeners();

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
        notifyListeners();
      }
    }
  }

  Future<bool> refreshIfStale() {
    return isStatusStale ? load(forceRefresh: true) : Future<bool>.value(true);
  }

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
    notifyListeners();

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
        notifyListeners();
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
    notifyListeners();

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
        notifyListeners();
      }
    }
  }

  PolicyDocument? historyDocumentFor(PolicyType type, int version) {
    return historyDocuments[_historyKey(type, version)];
  }

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
      notifyListeners();
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
    notifyListeners();

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
        notifyListeners();
      } else if (state != PolicyViewState.unauthorized &&
          state != PolicyViewState.forbidden) {
        state = PolicyViewState.accepted;
        successMessage = message;
        errorMessage =
            'Acceptance was committed, but status refresh is unavailable.';
        notifyListeners();
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

  void clear() {
    _operationEpoch += 1;
    _historyEpoch += 1;
    _statusRequestInFlight = false;
    _statusLoadedAt = null;
    consentStatus = null;
    lastAcceptance = null;
    documents.clear();
    staleDocuments.clear();
    histories.clear();
    historyDocuments.clear();
    historyErrors.clear();
    _historyLoading.clear();
    _historyVersionLoading.clear();
    errorMessage = null;
    successMessage = null;
    retryAfter = null;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    state = PolicyViewState.signedOut;
    policyApi.clearPublicCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    super.dispose();
  }

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
    notifyListeners();
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
      notifyListeners();
      return true;
    }

    if (state != PolicyViewState.unauthorized &&
        state != PolicyViewState.forbidden) {
      await _setFailure(originalError);
      errorMessage = 'The acceptance result is unknown. We refreshed your consent status; retry only after reviewing it.';
      notifyListeners();
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
      notifyListeners();
      return;
    }
    if (error is TokenStorageException) {
      state = PolicyViewState.retryableError;
      errorMessage =
          'Secure session storage is unavailable. Unlock your keyring and retry.';
      successMessage = null;
      notifyListeners();
      return;
    }
    state = PolicyViewState.retryableError;
    errorMessage = 'We could not load policy information. Please retry.';
    successMessage = null;
    notifyListeners();
  }

  String _contractFailureMessage(ApiContractException error) {
    return switch (error.field) {
      'policy.consent.response' =>
        'The policy status response was empty or invalid. Confirm the API returns JSON, then retry.',
      'policy.consent.data' =>
        'The policy status response is missing its policy data object. Confirm the API response envelope, then retry.',
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
      notifyListeners();
      return;
    }
    if (error.statusCode == 403) {
      state = PolicyViewState.forbidden;
      errorMessage = error.message.isEmpty
          ? 'Your account is not currently eligible for policy consent.'
          : error.message;
      notifyListeners();
      return;
    }
    if (error.statusCode == 422) {
      state = PolicyViewState.validationError;
      errorMessage = 'Confirm the policy checkbox before trying again.';
      notifyListeners();
      return;
    }
    if (error.statusCode == 429) {
      state = PolicyViewState.rateLimited;
      final duration = error.retryAfter ?? const Duration(seconds: 1);
      _rateLimitTimer?.cancel();
      _rateLimitTimer = Timer(duration, () {
        _rateLimitTimer = null;
        retryAfter = null;
        notifyListeners();
      });
      errorMessage = duration.inSeconds <= 1
          ? 'Too many attempts. Try again in a moment.'
          : 'Too many attempts. Try again in ${duration.inSeconds} seconds.';
      notifyListeners();
      return;
    }
    if (error.isNetworkError) {
      state = error.networkFailure == ApiNetworkFailure.timeout
          ? PolicyViewState.timeout
          : PolicyViewState.offline;
      errorMessage = error.networkFailure == ApiNetworkFailure.timeout
          ? 'The policy request timed out. Check your connection and retry.'
          : 'The policy service is unavailable offline. Reconnect and retry.';
      notifyListeners();
      return;
    }
    state = PolicyViewState.retryableError;
    if (error.statusCode == 404) {
      errorMessage =
          'The policy consent endpoint is unavailable on this API. Deploy the policy routes and retry.';
    } else if (error.statusCode != null && error.statusCode! >= 500) {
      errorMessage =
          'The policy service returned a server error. Check the policy migrations and seed data, then retry.';
    } else {
      errorMessage = 'We could not load policy information. Please retry.';
    }
    notifyListeners();
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

  String _historyKey(PolicyType type, int version) {
    return '${type.apiValue}:$version';
  }
}
