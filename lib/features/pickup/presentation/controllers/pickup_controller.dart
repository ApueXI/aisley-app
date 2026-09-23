import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/pickup_repository.dart';
import '../../domain/pickup_models.dart';

part 'pickup_controller_reads.dart';
part 'pickup_controller_actions.dart';
part 'pickup_controller_errors.dart';
part 'pickup_controller_state.dart';
part 'pickup_controller_attempts.dart';

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
  final Map<String, FinalMilePickupSubmission> hubPickupSubmissions =
      <String, FinalMilePickupSubmission>{};

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
  final Map<String, _PendingHubPickupAttempt> _pendingHubPickups =
      <String, _PendingHubPickupAttempt>{};
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

  bool hasPendingAttempt(PickupTask task) => task.isFinalMile
      ? _pendingHubPickups.containsKey(_taskKey(task))
      : _pendingAttempts.containsKey(_taskKey(task));

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
    hubPickupSubmissions.clear();
    routeManifests.clear();
    routeStatuses.clear();
    routeErrors.clear();
    _actionStatuses.clear();
    _actionErrors.clear();
    _actionRetryAfter.clear();
    _pendingAttempts.clear();
    _pendingHubPickups.clear();
    _pendingRejections.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _notifyPickupListeners() => notifyListeners();

  static bool _validIdentifier(String type, String identifier) {
    return (type == 'qr' || type == 'tracking_id' || type == 'order_id') &&
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
