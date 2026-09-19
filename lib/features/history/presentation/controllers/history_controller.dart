import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/history_repository.dart';
import '../../domain/history_models.dart';

typedef HistoryAuthFailureHandler = Future<void> Function(ApiException error);

enum HistoryLoadStatus {
  idle,
  loading,
  loaded,
  empty,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

class HistoryController extends ChangeNotifier {
  HistoryController({required this.historyRepository, this.onAuthFailure});

  final HistoryRepository historyRepository;
  final HistoryAuthFailureHandler? onAuthFailure;

  HistoryLoadStatus status = HistoryLoadStatus.idle;
  List<DeliveryHistoryItem> items = const <DeliveryHistoryItem>[];
  bool hasMore = false;
  String? nextCursor;
  String? errorMessage;
  Duration? retryAfter;
  DeliveryHistoryItem? detail;
  HistoryLoadStatus detailStatus = HistoryLoadStatus.idle;
  String? detailErrorMessage;

  Timer? _retryTimer;
  bool _loading = false;
  bool _authFailureNotified = false;

  bool get canRetryRateLimit => _retryTimer == null;

  Future<void> load({String? reference}) async {
    if (_loading || !canRetryRateLimit) {
      return;
    }
    _loading = true;
    _authFailureNotified = false;
    status = HistoryLoadStatus.loading;
    errorMessage = null;
    retryAfter = null;
    notifyListeners();
    try {
      final page = await historyRepository.fetchHistory(reference: reference);
      items = List<DeliveryHistoryItem>.unmodifiable(page.items);
      hasMore = page.hasMore;
      nextCursor = page.nextCursor;
      status = page.items.isEmpty
          ? HistoryLoadStatus.empty
          : HistoryLoadStatus.loaded;
      errorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setListError(error);
    } on TokenStorageException {
      status = HistoryLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Delivery history cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      status = HistoryLoadStatus.failed;
      errorMessage =
          'The delivery history response was not understood. Please retry.';
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  Future<void> loadDetail(String taskId) async {
    detailStatus = HistoryLoadStatus.loading;
    detailErrorMessage = null;
    notifyListeners();
    try {
      detail = await historyRepository.fetchDetail(taskId);
      detailStatus = HistoryLoadStatus.loaded;
      notifyListeners();
    } on ApiException catch (error) {
      detailStatus = _stateFor(error);
      detailErrorMessage = _messageForError(error);
      if (detailStatus == HistoryLoadStatus.rateLimited) {
        _startRetryDelay(error.retryAfter);
      }
      notifyListeners();
      if (error.statusCode == 401) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      detailStatus = HistoryLoadStatus.secureStorageFailure;
      detailErrorMessage = 'Secure session storage is unavailable. This delivery cannot be opened.';
      notifyListeners();
    } on ApiContractException {
      detailStatus = HistoryLoadStatus.failed;
      detailErrorMessage =
          'The delivery history response was not understood. Please retry.';
      notifyListeners();
    }
  }

  Future<void> retry() => load();

  void clear() {
    _retryTimer?.cancel();
    _retryTimer = null;
    status = HistoryLoadStatus.idle;
    items = const <DeliveryHistoryItem>[];
    hasMore = false;
    nextCursor = null;
    errorMessage = null;
    retryAfter = null;
    detail = null;
    detailStatus = HistoryLoadStatus.idle;
    detailErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _setListError(ApiException error) async {
    status = _stateFor(error);
    errorMessage = _messageForError(error);
    if (status == HistoryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
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
      notifyListeners();
    });
    retryAfter = delay;
  }

  HistoryLoadStatus _stateFor(ApiException error) {
    if (error.statusCode == 401) {
      return HistoryLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? HistoryLoadStatus.consentRequired
          : HistoryLoadStatus.forbidden;
    }
    if (error.statusCode == 429) {
      return HistoryLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? HistoryLoadStatus.timeout
          : HistoryLoadStatus.offline;
    }
    return HistoryLoadStatus.failed;
  }

  String _messageForError(ApiException error) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current Terms of Service and Privacy Policy before viewing delivery history.';
    }
    if (error.statusCode == 404) {
      return 'This delivery history record is unavailable.';
    }
    if (error.statusCode == 429) {
      return 'Too many requests. Wait before trying again.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'The request timed out. Retry when the service is reachable.'
          : 'The service is unreachable. Reconnect and retry.';
    }
    if (error.statusCode == 401) {
      return 'Your Courier session is no longer valid.';
    }
    if (error.statusCode == 403) {
      return error.message.isEmpty
          ? 'Delivery history is not available to your Courier account.'
          : error.message;
    }
    return 'The delivery history service could not complete the request. Please retry.';
  }
}
