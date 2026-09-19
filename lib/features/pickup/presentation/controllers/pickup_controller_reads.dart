part of 'pickup_controller.dart';

extension PickupControllerReads on PickupController {
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
    _notifyPickupListeners();

    await Future.wait<void>(<Future<void>>[
      _loadFirstMile(epoch),
      _loadFinalMile(epoch),
    ]);

    if (epoch == _loadEpoch) {
      _loadInFlight = false;
      _notifyPickupListeners();
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
      _notifyPickupListeners();
    } on ApiException catch (error) {
      await _setSectionError(firstMile: true, error: error, epoch: epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      firstMileStatus = PickupSectionStatus.secureStorageFailure;
      firstMileErrorMessage = 'Secure session storage is unavailable. Pickup work cannot be loaded.';
      _notifyPickupListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      firstMileStatus = PickupSectionStatus.failed;
      firstMileErrorMessage =
          'The pickup service returned an unexpected response. Please retry.';
      _notifyPickupListeners();
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
      _notifyPickupListeners();
    } on ApiException catch (error) {
      await _setSectionError(firstMile: false, error: error, epoch: epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileStatus = PickupSectionStatus.secureStorageFailure;
      finalMileErrorMessage = 'Secure session storage is unavailable. Pickup work cannot be loaded.';
      _notifyPickupListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileStatus = PickupSectionStatus.failed;
      finalMileErrorMessage = 'The hub pickup service returned an unexpected response. Please retry.';
      _notifyPickupListeners();
    }
  }

  Future<PickupRouteManifest?> loadRouteManifest(String scheduleId) async {
    final key = scheduleId.trim();
    if (key.isEmpty || routeStatuses[key] == PickupSectionStatus.loading) {
      return routeManifests[key];
    }

    routeStatuses[key] = PickupSectionStatus.loading;
    routeErrors[key] = null;
    _notifyPickupListeners();
    try {
      final manifest = await pickupRepository.fetchRouteManifest(key);
      routeManifests[key] = manifest;
      routeStatuses[key] = manifest.status == RouteManifestStatus.unavailable
          ? PickupSectionStatus.failed
          : PickupSectionStatus.loaded;
      _notifyPickupListeners();
      return manifest;
    } on ApiException catch (error) {
      routeStatuses[key] = _sectionStateFor(error);
      routeErrors[key] = _messageForError(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      _notifyPickupListeners();
      if (error.statusCode == 401) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      routeStatuses[key] = PickupSectionStatus.secureStorageFailure;
      routeErrors[key] =
          'Secure session storage is unavailable. The route cannot be loaded.';
      _notifyPickupListeners();
    } on ApiContractException {
      routeStatuses[key] = PickupSectionStatus.failed;
      routeErrors[key] =
          'The route service returned an unexpected response. Please retry.';
      _notifyPickupListeners();
    }
    return routeManifests[key];
  }

  Future<void> retry() => load();

  void clearResolution() {
    lastWaybillResolution = null;
    waybillResolutionError = null;
    waybillResolutionStatus = null;
    _notifyPickupListeners();
  }
}
