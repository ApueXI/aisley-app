import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/policy_repository.dart';
import '../../domain/policy_models.dart';

part 'policy_controller_reads.dart';
part 'policy_controller_history.dart';
part 'policy_controller_acceptance.dart';
part 'policy_controller_errors.dart';

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

  PolicyDocument? historyDocumentFor(PolicyType type, int version) {
    return historyDocuments[_historyKey(type, version)];
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

  void _notifyPolicyListeners() => notifyListeners();

  String _historyKey(PolicyType type, int version) {
    return '${type.apiValue}:$version';
  }
}
