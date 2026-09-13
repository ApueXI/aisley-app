import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../data/pickup_repository.dart';
import '../domain/pickup_models.dart';

typedef PickupAuthFailureHandler = Future<void> Function(ApiException error);

enum PickupSectionStatus {
  idle,
  loading,
  loaded,
  empty,
  failed,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  secureStorageFailure,
}

enum PickupTaskActionStatus {
  idle,
  accepting,
  accepted,
  rejecting,
  rejected,
  confirming,
  awaitingValidation,
  succeeded,
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

class PickupController extends ChangeNotifier {
  PickupController({required this.pickupRepository, this.onAuthFailure});

  final PickupRepository pickupRepository;
  final PickupAuthFailureHandler? onAuthFailure;

  PickupSectionStatus firstMileStatus = PickupSectionStatus.idle;
  PickupSectionStatus finalMileStatus = PickupSectionStatus.idle;
  List<PickupTask> firstMileTasks = const <PickupTask>[];
  List<PickupTask> finalMileTasks = const <PickupTask>[];
  FirstMileTaskPage? firstMilePage;
  String? firstMileErrorMessage;
  String? finalMileErrorMessage;
  Duration? retryAfter;

  WaybillResolution? lastWaybillResolution;
  String? waybillResolutionError;
  PickupSectionStatus? waybillResolutionStatus;
  FirstMilePickupResult? lastFirstMilePickup;
  FinalMilePickupSubmission? lastFinalMilePickup;

  final Map<String, PickupRouteManifest> routeManifests =
      <String, PickupRouteManifest>{};
  final Map<String, PickupSectionStatus> routeStatuses =
      <String, PickupSectionStatus>{};
  final Map<String, String?> routeErrors = <String, String?>{};

  final Map<String, PickupTaskActionStatus> _actionStatuses =
      <String, PickupTaskActionStatus>{};
  final Map<String, String?> _actionErrors = <String, String?>{};
  final Map<String, Duration?> _actionRetryAfter = <String, Duration?>{};
  final Map<String, _PendingPickupAttempt> _pendingAttempts =
      <String, _PendingPickupAttempt>{};
  final Map<String, _PendingRejectionAttempt> _pendingRejections =
      <String, _PendingRejectionAttempt>{};

  int _loadEpoch = 0;
  bool _loadInFlight = false;
  bool _authFailureNotified = false;
  Timer? _retryTimer;

  bool get isLoading =>
      firstMileStatus == PickupSectionStatus.loading ||
      finalMileStatus == PickupSectionStatus.loading;

  bool get hasLoadedAnySection =>
      firstMileStatus == PickupSectionStatus.loaded ||
      firstMileStatus == PickupSectionStatus.empty ||
      finalMileStatus == PickupSectionStatus.loaded ||
      finalMileStatus == PickupSectionStatus.empty;

  bool get canRetryRateLimit => _retryTimer == null;

  PickupTaskActionStatus actionStatus(PickupTask task) {
    return _actionStatuses[_taskKey(task)] ?? PickupTaskActionStatus.idle;
  }

  String? actionError(PickupTask task) => _actionErrors[_taskKey(task)];

  Duration? actionRetryAfter(PickupTask task) =>
      _actionRetryAfter[_taskKey(task)];

  bool isActionBusy(PickupTask task) {
    final status = actionStatus(task);
    return status == PickupTaskActionStatus.accepting ||
        status == PickupTaskActionStatus.rejecting ||
        status == PickupTaskActionStatus.confirming;
  }

  bool hasPendingAttempt(PickupTask task) =>
      _pendingAttempts.containsKey(_taskKey(task));

  bool hasPendingRejection(PickupTask task) =>
      _pendingRejections.containsKey(_taskKey(task));

  PickupTask taskWithId(PickupTask task) {
    final tasks = task.isFirstMile ? firstMileTasks : finalMileTasks;
    for (final candidate in tasks) {
      if (_taskKey(candidate) == _taskKey(task)) {
        return candidate;
      }
    }
    return task;
  }

  Future<void> load() async {
    if (_loadInFlight || !canRetryRateLimit) {
      return;
    }

    final epoch = ++_loadEpoch;
    _loadInFlight = true;
    _authFailureNotified = false;
    retryAfter = null;
    firstMileStatus = PickupSectionStatus.loading;
    finalMileStatus = PickupSectionStatus.loading;
    firstMileErrorMessage = null;
    finalMileErrorMessage = null;
    notifyListeners();

    await Future.wait<void>(<Future<void>>[
      _loadFirstMile(epoch),
      _loadFinalMile(epoch),
    ]);

    if (epoch == _loadEpoch) {
      _loadInFlight = false;
      notifyListeners();
    }
  }

  Future<void> _loadFirstMile(int epoch) async {
    try {
      final page = await pickupRepository.fetchFirstMileTasks();
      if (epoch != _loadEpoch) {
        return;
      }
      firstMilePage = page;
      firstMileTasks = List<PickupTask>.unmodifiable(page.tasks);
      firstMileStatus = page.tasks.isEmpty
          ? PickupSectionStatus.empty
          : PickupSectionStatus.loaded;
      firstMileErrorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setSectionError(firstMile: true, error: error, epoch: epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      firstMileStatus = PickupSectionStatus.secureStorageFailure;
      firstMileErrorMessage = 'Secure session storage is unavailable. Pickup work cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      firstMileStatus = PickupSectionStatus.failed;
      firstMileErrorMessage =
          'The pickup service returned an unexpected response. Please retry.';
      notifyListeners();
    }
  }

  Future<void> _loadFinalMile(int epoch) async {
    try {
      final tasks = await pickupRepository.fetchFinalMileTasks();
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileTasks = List<PickupTask>.unmodifiable(tasks);
      finalMileStatus = tasks.isEmpty
          ? PickupSectionStatus.empty
          : PickupSectionStatus.loaded;
      finalMileErrorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setSectionError(firstMile: false, error: error, epoch: epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileStatus = PickupSectionStatus.secureStorageFailure;
      finalMileErrorMessage = 'Secure session storage is unavailable. Pickup work cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileStatus = PickupSectionStatus.failed;
      finalMileErrorMessage = 'The hub pickup service returned an unexpected response. Please retry.';
      notifyListeners();
    }
  }

  Future<void> _setSectionError({
    required bool firstMile,
    required ApiException error,
    required int epoch,
  }) async {
    if (epoch != _loadEpoch) {
      return;
    }

    final state = _sectionStateFor(error);
    final message = _messageForError(error);
    if (firstMile) {
      firstMileStatus = state;
      firstMileErrorMessage = message;
    } else {
      finalMileStatus = state;
      finalMileErrorMessage = message;
    }
    if (state == PickupSectionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();

    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  Future<bool> acceptTask(PickupTask task) async {
    if (!task.isAssigned || isActionBusy(task)) {
      return false;
    }

    final key = _taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.accepting;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    notifyListeners();

    try {
      final accepted = task.isFirstMile
          ? await pickupRepository.acceptFirstMileTask(task.id)
          : await pickupRepository.acceptFinalMileTask(task.id);
      _replaceTask(accepted);
      _actionStatuses[key] = PickupTaskActionStatus.accepted;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<WaybillResolution?> resolveWaybill(String payload) async {
    waybillResolutionError = null;
    lastWaybillResolution = null;
    waybillResolutionStatus = null;
    try {
      final resolution = await pickupRepository.resolveWaybill(payload);
      lastWaybillResolution = resolution;
      waybillResolutionStatus = PickupSectionStatus.loaded;
      notifyListeners();
      return resolution;
    } on ApiException catch (error) {
      waybillResolutionError = _messageForError(error);
      waybillResolutionStatus = _sectionStateFor(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      notifyListeners();
      if (error.statusCode == 401) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      waybillResolutionStatus = PickupSectionStatus.secureStorageFailure;
      waybillResolutionError =
          'Secure session storage is unavailable. The QR could not be checked.';
      notifyListeners();
    } on ApiContractException {
      waybillResolutionStatus = PickupSectionStatus.failed;
      waybillResolutionError = 'The QR response was not understood. Enter the Order reference instead.';
      notifyListeners();
    }
    return null;
  }

  Future<bool> rejectFinalMileTask(
    PickupTask task, {
    required String reason,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.deliveryAssigned ||
        isActionBusy(task)) {
      return false;
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.length < 3 || normalizedReason.length > 1000) {
      _setLocalValidationError(
        task,
        'Enter a rejection reason between 3 and 1,000 characters.',
      );
      return false;
    }

    final key = _taskKey(task);
    final pending = _pendingRejections[key];
    final attempt = pending != null && pending.reason == normalizedReason
        ? pending
        : _PendingRejectionAttempt(
            reason: normalizedReason,
            idempotencyKey: _newUuid(),
          );
    _pendingRejections[key] = attempt;
    return _performFinalMileRejection(task, attempt);
  }

  Future<bool> retryFinalMileRejection(PickupTask task) async {
    final attempt = _pendingRejections[_taskKey(task)];
    if (attempt == null || !task.isFinalMile) {
      return false;
    }
    return _performFinalMileRejection(task, attempt);
  }

  Future<bool> _performFinalMileRejection(
    PickupTask task,
    _PendingRejectionAttempt attempt,
  ) async {
    final key = _taskKey(task);
    if (isActionBusy(task)) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.rejecting;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    notifyListeners();

    try {
      final result = await pickupRepository.rejectFinalMileTask(
        taskId: task.id,
        reason: attempt.reason,
        idempotencyKey: attempt.idempotencyKey,
      );
      _pendingRejections.remove(key);
      _replaceTask(
        task.copyWith(
          rawStatus: result.status,
          rejectionReason: result.rejectionReason ?? attempt.reason,
          offerRespondedAt: result.respondedAt,
        ),
      );
      _actionStatuses[key] = PickupTaskActionStatus.rejected;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<bool> confirmFirstMilePickup(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) async {
    if (!task.isFirstMile || !task.isAccepted || isActionBusy(task)) {
      return false;
    }

    final normalizedIdentifier = identifier.trim();
    if (!_validIdentifier(identifierType, normalizedIdentifier)) {
      _setLocalValidationError(
        task,
        'Choose QR or Order ID/reference and enter a value up to 128 characters.',
      );
      return false;
    }

    final pending = _pendingAttempt(
      task,
      identifierType: identifierType,
      identifier: normalizedIdentifier,
    );
    return _performFirstMilePickup(task, pending);
  }

  Future<bool> retryFirstMilePickup(PickupTask task) async {
    final pending = _pendingAttempts[_taskKey(task)];
    if (pending == null || pending.leg != PickupTaskLeg.firstMile) {
      return false;
    }
    return _performFirstMilePickup(task, pending);
  }

  Future<bool> _performFirstMilePickup(
    PickupTask task,
    _PendingPickupAttempt pending,
  ) async {
    final key = _taskKey(task);
    if (isActionBusy(task)) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.confirming;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    notifyListeners();

    try {
      final result = await pickupRepository.confirmFirstMilePickup(
        taskId: task.id,
        identifierType: pending.identifierType,
        identifier: pending.identifier,
        idempotencyKey: pending.idempotencyKey,
      );
      lastFirstMilePickup = result;
      _pendingAttempts.remove(key);
      _replaceTask(
        task.copyWith(
          rawStatus: result.taskStatus,
          pickedUpAt: result.pickedUpAt,
        ),
      );
      _actionStatuses[key] = PickupTaskActionStatus.succeeded;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<bool> submitFinalMilePickup(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.deliveryAccepted ||
        task.revision == null ||
        isActionBusy(task)) {
      return false;
    }

    final normalizedIdentifier = identifier.trim();
    if (!_validIdentifier(identifierType, normalizedIdentifier)) {
      _setLocalValidationError(
        task,
        'Choose QR or Order ID/reference and enter a value up to 128 characters.',
      );
      return false;
    }

    final pending = _pendingAttempt(
      task,
      identifierType: identifierType,
      identifier: normalizedIdentifier,
    );
    return _performFinalMilePickup(task, pending);
  }

  Future<bool> retryFinalMilePickup(PickupTask task) async {
    final pending = _pendingAttempts[_taskKey(task)];
    if (pending == null || pending.leg != PickupTaskLeg.finalMile) {
      return false;
    }
    return _performFinalMilePickup(task, pending);
  }

  Future<bool> _performFinalMilePickup(
    PickupTask task,
    _PendingPickupAttempt pending,
  ) async {
    final key = _taskKey(task);
    if (isActionBusy(task) || task.revision == null) {
      return false;
    }
    _actionStatuses[key] = PickupTaskActionStatus.confirming;
    _actionErrors[key] = null;
    _actionRetryAfter[key] = null;
    notifyListeners();

    try {
      final result = await pickupRepository.submitFinalMilePickup(
        taskId: task.id,
        identifierType: pending.identifierType,
        identifier: pending.identifier,
        expectedRevision: task.revision!,
        idempotencyKey: pending.idempotencyKey,
      );
      lastFinalMilePickup = result;
      _pendingAttempts.remove(key);
      _actionStatuses[key] = PickupTaskActionStatus.awaitingValidation;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      await _setActionError(task, error);
    } on TokenStorageException {
      _setActionStorageError(task);
    } on ApiContractException {
      _setActionContractError(task);
    }
    return false;
  }

  Future<PickupRouteManifest?> loadRouteManifest(String scheduleId) async {
    final key = scheduleId.trim();
    if (key.isEmpty || routeStatuses[key] == PickupSectionStatus.loading) {
      return routeManifests[key];
    }

    routeStatuses[key] = PickupSectionStatus.loading;
    routeErrors[key] = null;
    notifyListeners();
    try {
      final manifest = await pickupRepository.fetchRouteManifest(key);
      routeManifests[key] = manifest;
      routeStatuses[key] = manifest.status == RouteManifestStatus.unavailable
          ? PickupSectionStatus.failed
          : PickupSectionStatus.loaded;
      notifyListeners();
      return manifest;
    } on ApiException catch (error) {
      routeStatuses[key] = _sectionStateFor(error);
      routeErrors[key] = _messageForError(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      notifyListeners();
      if (error.statusCode == 401) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      routeStatuses[key] = PickupSectionStatus.secureStorageFailure;
      routeErrors[key] =
          'Secure session storage is unavailable. The route cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      routeStatuses[key] = PickupSectionStatus.failed;
      routeErrors[key] =
          'The route service returned an unexpected response. Please retry.';
      notifyListeners();
    }
    return routeManifests[key];
  }

  Future<void> retry() => load();

  void clearResolution() {
    lastWaybillResolution = null;
    waybillResolutionError = null;
    waybillResolutionStatus = null;
    notifyListeners();
  }

  void clear() {
    _loadEpoch++;
    _loadInFlight = false;
    _authFailureNotified = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    retryAfter = null;
    firstMileStatus = PickupSectionStatus.idle;
    finalMileStatus = PickupSectionStatus.idle;
    firstMileTasks = const <PickupTask>[];
    finalMileTasks = const <PickupTask>[];
    firstMilePage = null;
    firstMileErrorMessage = null;
    finalMileErrorMessage = null;
    lastWaybillResolution = null;
    waybillResolutionError = null;
    waybillResolutionStatus = null;
    lastFirstMilePickup = null;
    lastFinalMilePickup = null;
    routeManifests.clear();
    routeStatuses.clear();
    routeErrors.clear();
    _actionStatuses.clear();
    _actionErrors.clear();
    _actionRetryAfter.clear();
    _pendingAttempts.clear();
    _pendingRejections.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _replaceTask(PickupTask updated) {
    if (updated.isFirstMile) {
      firstMileTasks = List<PickupTask>.unmodifiable(
        firstMileTasks
            .map((task) => _taskKey(task) == _taskKey(updated) ? updated : task)
            .toList(growable: false),
      );
    } else {
      finalMileTasks = List<PickupTask>.unmodifiable(
        finalMileTasks
            .map((task) => _taskKey(task) == _taskKey(updated) ? updated : task)
            .toList(growable: false),
      );
    }
  }

  Future<void> _setActionError(PickupTask task, ApiException error) async {
    final key = _taskKey(task);
    final state = _actionStateFor(error);
    _actionStatuses[key] = state;
    _actionErrors[key] = _messageForError(error);
    _actionRetryAfter[key] = error.retryAfter;
    if (state == PickupTaskActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401) {
      await _notifyAuthFailure(error);
    }
  }

  void _setLocalValidationError(PickupTask task, String message) {
    final key = _taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.validationError;
    _actionErrors[key] = message;
    _actionRetryAfter[key] = null;
    notifyListeners();
  }

  void _setActionStorageError(PickupTask task) {
    final key = _taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.secureStorageFailure;
    _actionErrors[key] =
        'Secure session storage is unavailable. The action was not submitted.';
    notifyListeners();
  }

  void _setActionContractError(PickupTask task) {
    final key = _taskKey(task);
    _actionStatuses[key] = PickupTaskActionStatus.failed;
    _actionErrors[key] =
        'The pickup service returned an unexpected response. Please retry.';
    notifyListeners();
  }

  _PendingPickupAttempt _pendingAttempt(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) {
    final key = _taskKey(task);
    final existing = _pendingAttempts[key];
    if (existing != null &&
        existing.identifierType == identifierType &&
        existing.identifier == identifier) {
      return existing;
    }

    final pending = _PendingPickupAttempt(
      leg: task.leg,
      identifierType: identifierType,
      identifier: identifier,
      idempotencyKey: _newUuid(),
    );
    _pendingAttempts[key] = pending;
    return pending;
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

  PickupSectionStatus _sectionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return PickupSectionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? PickupSectionStatus.consentRequired
          : PickupSectionStatus.forbidden;
    }
    if (error.statusCode == 429) {
      return PickupSectionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? PickupSectionStatus.timeout
          : PickupSectionStatus.offline;
    }
    return PickupSectionStatus.failed;
  }

  PickupTaskActionStatus _actionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return PickupTaskActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? PickupTaskActionStatus.consentRequired
          : PickupTaskActionStatus.forbidden;
    }
    if (error.statusCode == 409) {
      return PickupTaskActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return PickupTaskActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return PickupTaskActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? PickupTaskActionStatus.timeout
          : PickupTaskActionStatus.offline;
    }
    return PickupTaskActionStatus.failed;
  }

  String _messageForError(ApiException error) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current Terms of Service and Privacy Policy before pickup actions are available.';
    }
    if (error.statusCode == 404) {
      return 'This pickup is no longer available. Refresh to see the current work assigned to you.';
    }
    if (error.statusCode == 409) {
      return 'This pickup changed on the server. Refresh before trying again.';
    }
    if (error.statusCode == 422) {
      return error.message.isEmpty
          ? 'Check the identifier and try again.'
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
          ? 'This pickup is not available to your Courier account.'
          : error.message;
    }
    return 'The pickup service could not complete the request. Please retry.';
  }

  static bool _validIdentifier(String type, String identifier) {
    return (type == 'qr' || type == 'order_id') &&
        identifier.isNotEmpty &&
        identifier.length <= 128;
  }

  static String _taskKey(PickupTask task) => '${task.leg.apiValue}:${task.id}';

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

class _PendingPickupAttempt {
  const _PendingPickupAttempt({
    required this.leg,
    required this.identifierType,
    required this.identifier,
    required this.idempotencyKey,
  });

  final PickupTaskLeg leg;
  final String identifierType;
  final String identifier;
  final String idempotencyKey;
}

class _PendingRejectionAttempt {
  const _PendingRejectionAttempt({
    required this.reason,
    required this.idempotencyKey,
  });

  final String reason;
  final String idempotencyKey;
}
