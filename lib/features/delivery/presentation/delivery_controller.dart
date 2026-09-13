import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../../pickup/domain/pickup_models.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_models.dart';

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
  final Map<String, _PendingIdentifierAttempt> _pendingProofs =
      <String, _PendingIdentifierAttempt>{};
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
        status == DeliveryActionStatus.proofSubmitting ||
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
      DeliveryActionStatus.proofSubmitting ||
      DeliveryActionStatus.completionSubmitting => false,
      _ => true,
    };
  }

  bool hasPendingProof(PickupTask task) => _pendingProofs.containsKey(task.id);

  bool hasPendingCompletion(PickupTask task) =>
      _pendingCompletions.containsKey(task.id);

  bool isCompletionPending(PickupTask task) {
    final completion = completions[task.id];
    final proofId = proofs[task.id]?.proofId;
    final completionEvidenceId = completion?.evidenceId;
    final projectionMatchesCurrentProof =
        proofId == null ||
        completionEvidenceId == null ||
        completionEvidenceId == proofId;

    if (actionStatus(task) ==
            DeliveryActionStatus.completionAwaitingValidation &&
        projectionMatchesCurrentProof) {
      return true;
    }
    return completion?.isAwaitingValidation == true &&
        projectionMatchesCurrentProof;
  }

  Future<void> load() async {
    if (_loadInFlight || !canRetryRateLimit) {
      return;
    }
    final epoch = ++_loadEpoch;
    _loadInFlight = true;
    _authFailureNotified = false;
    retryAfter = null;
    loadStatus = DeliveryLoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedTasks = await deliveryRepository.fetchFinalMileTasks();
      if (epoch != _loadEpoch) {
        return;
      }
      tasks = List<PickupTask>.unmodifiable(loadedTasks);
      for (final task in loadedTasks) {
        if (_actionStatuses[task.id] == DeliveryActionStatus.conflict) {
          _actionStatuses.remove(task.id);
          _actionErrors.remove(task.id);
          _actionRetryAfter.remove(task.id);
        }
      }
      loadStatus = loadedTasks.isEmpty
          ? DeliveryLoadStatus.empty
          : DeliveryLoadStatus.loaded;
      errorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setLoadError(error, epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      loadStatus = DeliveryLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Delivery work cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      loadStatus = DeliveryLoadStatus.failed;
      errorMessage =
          'The delivery service returned an unexpected response. Please retry.';
      notifyListeners();
    } finally {
      if (epoch == _loadEpoch) {
        _loadInFlight = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadDetails(PickupTask task) async {
    final taskId = task.id;
    if (contextStatuses[taskId] == DeliveryLoadStatus.loading ||
        !canRetryRateLimit) {
      return;
    }
    contextStatuses[taskId] = DeliveryLoadStatus.loading;
    contextErrors[taskId] = null;
    notifyListeners();

    try {
      final context = await deliveryRepository.fetchDeliveryContext(taskId);
      contexts[taskId] = context;
      final currentTask = taskById(taskId);
      if (currentTask != null) {
        _replaceTask(
          currentTask.copyWith(
            rawStatus: context.status,
            revision: context.revision,
          ),
        );
      }
      contextStatuses[taskId] = DeliveryLoadStatus.loaded;
      contextErrors[taskId] = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setContextError(taskId, error);
    } on TokenStorageException {
      contextStatuses[taskId] = DeliveryLoadStatus.secureStorageFailure;
      contextErrors[taskId] = 'Secure session storage is unavailable. Delivery details cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      contextStatuses[taskId] = DeliveryLoadStatus.failed;
      contextErrors[taskId] =
          'The delivery details response was not understood. Please retry.';
      notifyListeners();
    }

    final current = taskById(taskId) ?? task;
    if (current.status == PickupTaskStatus.outForDelivery ||
        current.status == PickupTaskStatus.delivered) {
      await loadCompletion(current);
    }
  }

  Future<void> loadCompletion(PickupTask task) async {
    final taskId = task.id;
    if (completionStatuses[taskId] == DeliveryLoadStatus.loading ||
        !canRetryRateLimit) {
      return;
    }
    completionStatuses[taskId] = DeliveryLoadStatus.loading;
    completionErrors[taskId] = null;
    notifyListeners();
    try {
      final completion = await deliveryRepository.fetchCompletion(taskId);
      completions[taskId] = completion;
      completionStatuses[taskId] = DeliveryLoadStatus.loaded;
      completionErrors[taskId] = null;
      _syncTaskFromCompletion(task, completion);
      _reconcileActionWithCompletion(taskId, completion);
      notifyListeners();
    } on ApiException catch (error) {
      await _setCompletionError(taskId, error);
    } on TokenStorageException {
      completionStatuses[taskId] = DeliveryLoadStatus.secureStorageFailure;
      completionErrors[taskId] = 'Secure session storage is unavailable. Completion status cannot be loaded.';
      notifyListeners();
    } on ApiContractException catch (error) {
      completionStatuses[taskId] = DeliveryLoadStatus.failed;
      completionErrors[taskId] = _contractFailureMessage(error);
      notifyListeners();
    }
  }

  Future<bool> advanceStatus(PickupTask task) async {
    final nextStatus = nextStatusFor(task.status);
    final revision = task.revision;
    if (!task.isFinalMile || nextStatus == null || revision == null) {
      return false;
    }
    final taskId = task.id;
    if (!canStartAction(task)) {
      return false;
    }
    _actionStatuses[taskId] = DeliveryActionStatus.moving;
    _actionErrors[taskId] = null;
    _actionRetryAfter[taskId] = null;
    notifyListeners();
    try {
      final update = await deliveryRepository.advanceStatus(
        taskId: taskId,
        status: nextStatus,
        expectedRevision: revision,
      );
      final updated = task.copyWith(
        rawStatus: update.status,
        revision: update.revision,
      );
      _replaceTask(updated);
      final context = contexts[taskId];
      if (context != null) {
        contexts[taskId] = context.copyWith(
          status: update.status,
          revision: update.revision,
        );
      }
      _actionStatuses[taskId] = DeliveryActionStatus.moved;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }

  Future<bool> submitProof(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    final normalizedIdentifier = identifierType == 'qr'
        ? identifier
        : identifier.trim();
    if (task.revision == null) {
      _setLocalValidationError(
        task,
        'The task revision is unavailable. Refresh the task before submitting proof.',
      );
      return false;
    }
    if (!_validIdentifier(identifierType, normalizedIdentifier)) {
      _setLocalValidationError(
        task,
        'Choose QR or enter a public Order reference up to 128 characters.',
      );
      return false;
    }
    if (identifierType == 'order_id') {
      final publicOrderReference = task.order?.reference?.trim();
      if (publicOrderReference == null || publicOrderReference.isEmpty) {
        _setLocalValidationError(
          task,
          'The public Order reference is unavailable. Use the delivery QR instead.',
        );
        return false;
      }
      final orderDatabaseId = task.order?.id?.trim();
      final waybillReference = task.waybill?.reference?.trim();
      final waybillDatabaseId = task.waybill?.id?.trim();
      if (normalizedIdentifier == orderDatabaseId ||
          normalizedIdentifier == waybillReference ||
          normalizedIdentifier == waybillDatabaseId) {
        _setLocalValidationError(
          task,
          'Enter the public Order reference shown above. Database IDs and waybill references are not accepted here.',
        );
        return false;
      }
    }
    final existing = _pendingProofs[task.id];
    final attempt =
        existing != null &&
            existing.identifierType == identifierType &&
            existing.identifier == normalizedIdentifier
        ? existing
        : _PendingIdentifierAttempt(
            identifierType: identifierType,
            identifier: normalizedIdentifier,
            expectedRevision: task.revision!,
            idempotencyKey: _newUuid(),
          );
    _pendingProofs[task.id] = attempt;
    return _performProof(task, attempt);
  }

  Future<bool> retryProof(PickupTask task) async {
    final attempt = _pendingProofs[task.id];
    if (attempt == null) {
      return false;
    }
    return _performProof(task, attempt);
  }

  Future<bool> _performProof(
    PickupTask task,
    _PendingIdentifierAttempt attempt,
  ) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.proofSubmitting;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    notifyListeners();
    try {
      final proof = await deliveryRepository.submitProof(
        taskId: task.id,
        identifierType: attempt.identifierType,
        identifier: attempt.identifier,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
      );
      proofs[task.id] = proof;
      _pendingProofs.remove(task.id);
      _actionStatuses[task.id] = DeliveryActionStatus.proofAwaitingValidation;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (_isDefinitiveMutationError(error)) {
        _pendingProofs.remove(task.id);
      }
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }

  Future<bool> submitCompletion(
    PickupTask task, {
    required String evidenceId,
  }) async {
    final normalizedEvidenceId = evidenceId.trim();
    final latestRevision = _latestRevision(task);
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        latestRevision == null ||
        normalizedEvidenceId.isEmpty ||
        isCompletionPending(task) ||
        completions[task.id]?.isDelivered == true ||
        !canStartAction(task)) {
      return false;
    }
    final knownProofId =
        proofs[task.id]?.proofId ?? completions[task.id]?.evidenceId;
    if (knownProofId == null || knownProofId != normalizedEvidenceId) {
      _setLocalValidationError(
        task,
        'Submit proof for this delivery first. Only its server-returned proof ID can be used for completion.',
      );
      return false;
    }
    final existing = _pendingCompletions[task.id];
    final attempt =
        existing != null && existing.evidenceId == normalizedEvidenceId
        ? existing
        : _PendingCompletionAttempt(
            evidenceId: normalizedEvidenceId,
            expectedRevision: latestRevision,
            idempotencyKey: _newUuid(),
          );
    _pendingCompletions[task.id] = attempt;
    return _performCompletion(task, attempt);
  }

  Future<bool> retryCompletion(PickupTask task) async {
    final attempt = _pendingCompletions[task.id];
    if (attempt == null) {
      return false;
    }
    return _performCompletion(task, attempt);
  }

  Future<bool> _performCompletion(
    PickupTask task,
    _PendingCompletionAttempt attempt,
  ) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        completions[task.id]?.isDelivered == true ||
        !canStartAction(task)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.completionSubmitting;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    notifyListeners();
    try {
      final completion = await deliveryRepository.submitCompletion(
        taskId: task.id,
        expectedRevision: attempt.expectedRevision,
        evidenceId: attempt.evidenceId,
        idempotencyKey: attempt.idempotencyKey,
      );
      completions[task.id] = completion;
      _pendingCompletions.remove(task.id);
      _syncTaskFromCompletion(task, completion, allowDelivered: false);
      _actionStatuses[task.id] =
          DeliveryActionStatus.completionAwaitingValidation;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (_isDefinitiveMutationError(error)) {
        _pendingCompletions.remove(task.id);
      }
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException catch (error) {
      _setContractActionError(task, error);
    }
    return false;
  }

  Future<void> retry() => load();

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
    _pendingProofs.clear();
    _pendingCompletions.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _setLoadError(ApiException error, int epoch) async {
    if (epoch != _loadEpoch) {
      return;
    }
    loadStatus = _loadStateFor(error);
    errorMessage = _messageForError(error);
    if (loadStatus == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setContextError(String taskId, ApiException error) async {
    contextStatuses[taskId] = _loadStateFor(error);
    contextErrors[taskId] = _messageForError(error);
    if (contextStatuses[taskId] == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setCompletionError(String taskId, ApiException error) async {
    completionStatuses[taskId] = _loadStateFor(error);
    completionErrors[taskId] = _messageForError(error);
    if (completionStatuses[taskId] == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setActionError(PickupTask task, ApiException error) async {
    _actionStatuses[task.id] = _actionStateFor(error);
    _actionErrors[task.id] = _messageForError(error);
    _actionRetryAfter[task.id] = error.retryAfter;
    if (_actionStatuses[task.id] == DeliveryActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  void _setLocalValidationError(PickupTask task, String message) {
    _actionStatuses[task.id] = DeliveryActionStatus.validationError;
    _actionErrors[task.id] = message;
    _actionRetryAfter[task.id] = null;
    notifyListeners();
  }

  void _setStorageActionError(PickupTask task) {
    _actionStatuses[task.id] = DeliveryActionStatus.secureStorageFailure;
    _actionErrors[task.id] =
        'Secure session storage is unavailable. The action was not submitted.';
    notifyListeners();
  }

  void _setContractActionError(PickupTask task, ApiContractException error) {
    _actionStatuses[task.id] = DeliveryActionStatus.failed;
    _actionErrors[task.id] = _contractFailureMessage(error);
    notifyListeners();
  }

  String _contractFailureMessage(ApiContractException error) {
    return 'The delivery response does not match the documented API contract (${error.field}). Please retry.';
  }

  void _replaceTask(PickupTask updated) {
    tasks = List<PickupTask>.unmodifiable(
      tasks.map((task) => task.id == updated.id ? updated : task),
    );
  }

  void _syncTaskFromCompletion(
    PickupTask task,
    CompletionProjection completion, {
    bool allowDelivered = true,
  }) {
    final status = completion.isDelivered && !allowDelivered
        ? task.rawStatus
        : completion.taskStatus;
    _replaceTask(
      task.copyWith(rawStatus: status, revision: completion.revision),
    );
    if (completion.isDelivered && allowDelivered) {
      _actionStatuses[task.id] = DeliveryActionStatus.completed;
    }
  }

  void _reconcileActionWithCompletion(
    String taskId,
    CompletionProjection completion,
  ) {
    if (completion.isDelivered) {
      return;
    }
    if (completion.isAwaitingValidation &&
        _completionMatchesCurrentProof(taskId, completion)) {
      _actionStatuses[taskId] =
          DeliveryActionStatus.completionAwaitingValidation;
      _actionErrors.remove(taskId);
      _actionRetryAfter.remove(taskId);
      return;
    }
    final actionStatus = _actionStatuses[taskId];
    if (actionStatus == DeliveryActionStatus.conflict ||
        actionStatus == DeliveryActionStatus.proofAwaitingValidation ||
        actionStatus == DeliveryActionStatus.completionAwaitingValidation) {
      _actionStatuses.remove(taskId);
      _actionErrors.remove(taskId);
      _actionRetryAfter.remove(taskId);
    }
  }

  bool _completionMatchesCurrentProof(
    String taskId,
    CompletionProjection completion,
  ) {
    final proofId = proofs[taskId]?.proofId;
    final evidenceId = completion.evidenceId;
    return proofId == null || evidenceId == null || proofId == evidenceId;
  }

  int? _latestRevision(PickupTask task) {
    final taskRevision = task.revision;
    final projectionRevision = completions[task.id]?.revision;
    if (taskRevision == null) {
      return projectionRevision;
    }
    if (projectionRevision == null) {
      return taskRevision;
    }
    return projectionRevision > taskRevision
        ? projectionRevision
        : taskRevision;
  }

  static bool _isDefinitiveMutationError(ApiException error) {
    return error.statusCode == 404 ||
        error.statusCode == 409 ||
        error.statusCode == 422;
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

  DeliveryLoadStatus _loadStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return DeliveryLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? DeliveryLoadStatus.consentRequired
          : DeliveryLoadStatus.forbidden;
    }
    if (error.statusCode == 429) {
      return DeliveryLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? DeliveryLoadStatus.timeout
          : DeliveryLoadStatus.offline;
    }
    return DeliveryLoadStatus.failed;
  }

  DeliveryActionStatus _actionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return DeliveryActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? DeliveryActionStatus.consentRequired
          : DeliveryActionStatus.forbidden;
    }
    if (error.statusCode == 409) {
      return DeliveryActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return DeliveryActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return DeliveryActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? DeliveryActionStatus.timeout
          : DeliveryActionStatus.offline;
    }
    return DeliveryActionStatus.failed;
  }

  String _messageForError(ApiException error) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current Terms of Service and Privacy Policy before delivery actions are available.';
    }
    if (error.code == 'PARCEL_NOT_FOUND') {
      return 'The scanned or entered identifier does not belong to this delivery. Use the public Order reference or the correct delivery QR.';
    }
    if (error.code == 'TASK_STATE_CONFLICT') {
      return 'The task state or revision changed. Refresh the task before trying again.';
    }
    if (error.code == 'COMPLETION_STATE_CONFLICT') {
      return 'The completion state changed. Refresh the task before trying again.';
    }
    if (error.statusCode == 404) {
      return 'This delivery is no longer available. Refresh to see current work.';
    }
    if (error.statusCode == 409) {
      if (error.code == 'PROOF_NOT_VALIDATED') {
        return 'Logistics has not validated the proof yet. Refresh before trying completion again.';
      }
      return 'This delivery changed on the server. Refresh before trying again.';
    }
    if (error.statusCode == 422) {
      return error.message.isEmpty
          ? 'Check the submitted delivery information and try again.'
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
          ? 'This delivery is not available to your Courier account.'
          : error.message;
    }
    return 'The delivery service could not complete the request. Please retry.';
  }

  static String? nextStatusFor(PickupTaskStatus status) {
    return switch (status) {
      PickupTaskStatus.pickedUpFromHub => 'in_transit',
      PickupTaskStatus.inTransit => 'out_for_delivery',
      _ => null,
    };
  }

  static bool _validIdentifier(String type, String identifier) {
    return (type == 'qr' || type == 'order_id') &&
        identifier.trim().isNotEmpty &&
        identifier.length <= 128;
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

class _PendingIdentifierAttempt {
  const _PendingIdentifierAttempt({
    required this.identifierType,
    required this.identifier,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String identifierType;
  final String identifier;
  final int expectedRevision;
  final String idempotencyKey;
}

class _PendingCompletionAttempt {
  const _PendingCompletionAttempt({
    required this.evidenceId,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String evidenceId;
  final int expectedRevision;
  final String idempotencyKey;
}
