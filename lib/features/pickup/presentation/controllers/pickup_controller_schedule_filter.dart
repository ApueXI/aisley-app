part of 'pickup_controller.dart';

extension PickupControllerScheduleFilter on PickupController {
  Future<void> selectFirstMileSchedule(String? scheduleId) async {
    final normalized = scheduleId?.trim();
    final selected = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (selected == _firstMileScheduleId ||
        (selected != null &&
            !_firstMileScheduleOptions.containsKey(selected))) {
      return;
    }
    _firstMileScheduleId = selected;
    // Never display rows from a different filter, including after a failed read.
    firstMileTasks = const <PickupTask>[];
    firstMilePage = null;
    _firstMileRequestId++;
    await reloadFirstMile();
  }

  Future<void> reloadFirstMile() async {
    if (!canRetryRateLimit) {
      firstMileStatus = PickupSectionStatus.rateLimited;
      firstMileErrorMessage = 'Please wait before retrying pickup work.';
      _notifyPickupListeners();
      return;
    }
    firstMileStatus = PickupSectionStatus.loading;
    firstMileErrorMessage = null;
    _notifyPickupListeners();
    await _loadFirstMile(_loadEpoch);
  }

  Future<void> _loadFirstMile(int epoch) async {
    final requestId = ++_firstMileRequestId;
    final scheduleId = _firstMileScheduleId;
    bool current() => epoch == _loadEpoch && requestId == _firstMileRequestId;
    try {
      final page = await pickupRepository.fetchFirstMileTasks(
        pickupScheduleId: scheduleId,
      );
      if (!current()) {
        return;
      }
      if (scheduleId != null &&
          page.tasks.any(
            (task) => !task.isFirstMile || _scheduleIdFor(task) != scheduleId,
          )) {
        throw const ApiContractException('pickup.first_mile.schedule_filter');
      }
      if (scheduleId == null) {
        _firstMileScheduleOptions.clear();
        for (final task in page.tasks) {
          final id = _scheduleIdFor(task);
          if (!task.isFirstMile || id == null) {
            continue;
          }
          if (_firstMileScheduleOptions.length >= 50 &&
              !_firstMileScheduleOptions.containsKey(id)) {
            break;
          }
          final reference = task.schedule?.reference?.trim();
          _firstMileScheduleOptions.putIfAbsent(
            id,
            () => reference == null || reference.isEmpty ? id : reference,
          );
        }
      }
      firstMilePage = page;
      firstMileTasks = List<PickupTask>.unmodifiable(page.tasks);
      firstMileStatus = page.tasks.isEmpty
          ? PickupSectionStatus.empty
          : PickupSectionStatus.loaded;
      firstMileErrorMessage = null;
      _notifyPickupListeners();
    } on ApiException catch (error) {
      if (!current()) {
        return;
      }
      await _setSectionError(firstMile: true, error: error, epoch: epoch);
    } on TokenStorageException {
      if (!current()) {
        return;
      }
      firstMileStatus = PickupSectionStatus.secureStorageFailure;
      firstMileErrorMessage = 'Secure session storage is unavailable. Pickup work cannot be loaded.';
      _notifyPickupListeners();
    } on ApiContractException {
      if (!current()) {
        return;
      }
      firstMileStatus = PickupSectionStatus.failed;
      firstMileErrorMessage =
          'The pickup service returned an unexpected response. Please retry.';
      _notifyPickupListeners();
    }
  }

  String? _scheduleIdFor(PickupTask task) {
    final id = (task.pickupScheduleId ?? task.schedule?.id)?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  void _clearFirstMileScheduleFilter() {
    _firstMileRequestId++;
    _firstMileScheduleId = null;
    _firstMileScheduleOptions.clear();
  }
}
