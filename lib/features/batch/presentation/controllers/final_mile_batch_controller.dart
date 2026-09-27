import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/final_mile_batch_repository.dart';
import '../../domain/final_mile_batch_models.dart';

part 'final_mile_batch_controller_actions.dart';
part 'final_mile_batch_controller_reads.dart';
part 'final_mile_batch_controller_support.dart';

typedef BatchAuthFailureHandler = Future<void> Function(ApiException error);
typedef BatchAcceptedHandler = Future<void> Function();

enum FinalMileBatchLoadStatus {
  idle,
  loading,
  loaded,
  empty,
  unavailable,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

enum FinalMileBatchActionStatus {
  idle,
  accepting,
  reconciling,
  accepted,
  conflict,
  unavailable,
  validationError,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

class FinalMileBatchController extends ChangeNotifier {
  FinalMileBatchController({
    required this.repository,
    this.onAuthFailure,
    this.onBatchAccepted,
  });

  final FinalMileBatchRepository repository;
  final BatchAuthFailureHandler? onAuthFailure;
  final BatchAcceptedHandler? onBatchAccepted;

  FinalMileBatchLoadStatus listStatus = FinalMileBatchLoadStatus.idle;
  List<FinalMileBatch> batches = const <FinalMileBatch>[];
  String? listError;
  Duration? retryAfter;

  final Map<String, FinalMileBatch> _details = <String, FinalMileBatch>{};
  final Map<String, FinalMileBatchLoadStatus> _detailStatuses =
      <String, FinalMileBatchLoadStatus>{};
  final Map<String, String?> _detailErrors = <String, String?>{};
  final Map<String, FinalMileBatchActionStatus> _actionStatuses =
      <String, FinalMileBatchActionStatus>{};
  final Map<String, String?> _actionErrors = <String, String?>{};
  final Set<String> _uncertainAcceptances = <String>{};

  int _epoch = 0;
  bool _listInFlight = false;
  bool _authFailureNotified = false;
  bool _disposed = false;
  Timer? _retryTimer;

  bool get canRetryRateLimit => _retryTimer == null;

  FinalMileBatch? batchById(String id) {
    final detail = _details[id];
    if (detail != null) return detail;
    for (final batch in batches) {
      if (batch.id == id) return batch;
    }
    return null;
  }

  FinalMileBatchLoadStatus detailStatus(String id) =>
      _detailStatuses[id] ?? FinalMileBatchLoadStatus.idle;

  String? detailError(String id) => _detailErrors[id];

  FinalMileBatchActionStatus actionStatus(String id) =>
      _actionStatuses[id] ?? FinalMileBatchActionStatus.idle;

  String? actionError(String id) => _actionErrors[id];

  bool isActionBusy(String id) {
    final status = actionStatus(id);
    return status == FinalMileBatchActionStatus.accepting ||
        status == FinalMileBatchActionStatus.reconciling;
  }

  void clear() {
    _epoch++;
    _listInFlight = false;
    _authFailureNotified = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    retryAfter = null;
    listStatus = FinalMileBatchLoadStatus.idle;
    batches = const <FinalMileBatch>[];
    listError = null;
    _details.clear();
    _detailStatuses.clear();
    _detailErrors.clear();
    _actionStatuses.clear();
    _actionErrors.clear();
    _uncertainAcceptances.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
