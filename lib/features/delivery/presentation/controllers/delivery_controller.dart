import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/networking/multipart_file_adapter.dart';
import '../../../../core/security/token_storage.dart';
import '../../../pickup/domain/pickup_models.dart';
import '../../data/delivery_repository.dart';
import '../../domain/delivery_models.dart';

part 'delivery_controller_reads.dart';
part 'delivery_controller_actions.dart';
part 'delivery_controller_errors.dart';
part 'delivery_controller_reconciliation.dart';
part 'delivery_controller_attempts.dart';
part 'delivery_controller_cod.dart';

typedef DeliveryAuthFailureHandler = Future<void> Function(ApiException error);

enum DeliveryLoadStatus {
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

enum DeliveryActionStatus {
  idle,
  loading,
  moving,
  moved,
  proofSubmitting,
  proofAwaitingValidation,
  completionLoading,
  completionSubmitting,
  completionAwaitingValidation,
  completed,
  validationError,
  conflict,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

class DeliveryController extends ChangeNotifier {
  DeliveryController({required this.deliveryRepository, this.onAuthFailure});

  final DeliveryRepository deliveryRepository;
  final DeliveryAuthFailureHandler? onAuthFailure;

  DeliveryLoadStatus loadStatus = DeliveryLoadStatus.idle;
  List<PickupTask> tasks = const <PickupTask>[];
  String? errorMessage;
  Duration? retryAfter;

  final Map<String, DeliveryContext> contexts = <String, DeliveryContext>{};
  final Map<String, DeliveryLoadStatus> contextStatuses =
      <String, DeliveryLoadStatus>{};
  final Map<String, String?> contextErrors = <String, String?>{};
  final Map<String, CompletionProjection> completions =
      <String, CompletionProjection>{};
  final Map<String, DeliveryLoadStatus> completionStatuses =
      <String, DeliveryLoadStatus>{};
  final Map<String, String?> completionErrors = <String, String?>{};
  final Map<String, ProofSubmission> proofs = <String, ProofSubmission>{};

  final Map<String, DeliveryActionStatus> _actionStatuses =
      <String, DeliveryActionStatus>{};
  final Map<String, String?> _actionErrors = <String, String?>{};
  final Map<String, Duration?> _actionRetryAfter = <String, Duration?>{};
  final Map<String, _PendingMovementAttempt> _pendingMovements =
      <String, _PendingMovementAttempt>{};
  final Map<String, _PendingPhotoAttempt> _pendingProofs =
      <String, _PendingPhotoAttempt>{};
  final Map<String, _PendingCompletionAttempt> _pendingCompletions =
      <String, _PendingCompletionAttempt>{};

  int _loadEpoch = 0;
  bool _loadInFlight = false;
  bool _authFailureNotified = false;
  Timer? _retryTimer;

  bool get isLoading => loadStatus == DeliveryLoadStatus.loading;

  bool get canRetryRateLimit => _retryTimer == null;

  PickupTask? taskById(String taskId) {
    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  DeliveryActionStatus actionStatus(PickupTask task) {
    return _actionStatuses[task.id] ?? DeliveryActionStatus.idle;
  }

  String? actionError(PickupTask task) => _actionErrors[task.id];

  Duration? actionRetryAfter(PickupTask task) => _actionRetryAfter[task.id];

  bool isActionBusy(PickupTask task) {
    final status = actionStatus(task);
    return status == DeliveryActionStatus.moving ||
        status == DeliveryActionStatus.loading ||
        status == DeliveryActionStatus.proofSubmitting ||
        status == DeliveryActionStatus.completionLoading ||
        status == DeliveryActionStatus.completionSubmitting;
  }

  bool canStartAction(PickupTask task) {
    if (!canRetryRateLimit) {
      return false;
    }
    return switch (actionStatus(task)) {
      DeliveryActionStatus.conflict ||
      DeliveryActionStatus.unauthorized ||
      DeliveryActionStatus.forbidden ||
      DeliveryActionStatus.consentRequired ||
      DeliveryActionStatus.moving ||
      DeliveryActionStatus.loading ||
      DeliveryActionStatus.proofSubmitting ||
      DeliveryActionStatus.completionLoading ||
      DeliveryActionStatus.completionSubmitting => false,
      _ => true,
    };
  }

  bool hasPendingProof(PickupTask task) => _pendingProofs.containsKey(task.id);

  bool hasPendingMovement(PickupTask task) =>
      _pendingMovements.containsKey(task.id);

  bool hasPendingCompletion(PickupTask task) =>
      _pendingCompletions.containsKey(task.id);

  bool isCompletionPending(PickupTask task) {
    final completion = completions[task.id];
    if (completion?.evidenceStatus == 'rejected' ||
        completion?.completionStatus == 'rejected') {
      return false;
    }
    final proofId = proofs[task.id]?.proofId;
    final completionEvidenceId = completion?.evidenceId;
    final projectionMatchesCurrentProof =
        proofId == null || completionEvidenceId == proofId;

    if (actionStatus(task) ==
            DeliveryActionStatus.completionAwaitingValidation &&
        projectionMatchesCurrentProof) {
      return true;
    }
    return completion?.isAwaitingValidation == true &&
        projectionMatchesCurrentProof;
  }

  String? evidenceStatusFor(PickupTask task) {
    final proof = proofs[task.id];
    final completion = completions[task.id];
    if (proof == null) return completion?.evidenceStatus;
    if (completion?.evidenceId == proof.proofId) {
      return completion?.evidenceStatus ?? proof.evidenceStatus;
    }
    return proof.evidenceStatus;
  }

  void clear() {
    _loadEpoch++;
    _loadInFlight = false;
    _authFailureNotified = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    loadStatus = DeliveryLoadStatus.idle;
    tasks = const <PickupTask>[];
    errorMessage = null;
    retryAfter = null;
    contexts.clear();
    contextStatuses.clear();
    contextErrors.clear();
    completions.clear();
    completionStatuses.clear();
    completionErrors.clear();
    proofs.clear();
    _actionStatuses.clear();
    _actionErrors.clear();
    _actionRetryAfter.clear();
    _pendingMovements.clear();
    _pendingProofs.clear();
    _pendingCompletions.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _notifyDeliveryListeners() => notifyListeners();

  static bool _isDefinitiveMutationError(ApiException error) {
    return error.statusCode == 404 ||
        error.statusCode == 409 ||
        error.statusCode == 422;
  }

  static String? nextStatusFor(PickupTaskStatus status) {
    return switch (status) {
      PickupTaskStatus.pickedUpFromHub => 'in_transit',
      PickupTaskStatus.inTransit => 'out_for_delivery',
      _ => null,
    };
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
