part of 'vehicle_controller.dart';

extension VehicleControllerReads on VehicleController {
  Future<void> load() async {
    if (_loading || !canRetryRateLimit) {
      return;
    }
    _loading = true;
    _authFailureNotified = false;
    retryAfter = null;
    loadStatus = VehicleLoadStatus.loading;
    errorMessage = null;
    _notifyVehicleListeners();

    try {
      final loadedVehicle = await vehicleRepository.fetchVehicle();
      vehicle = loadedVehicle;
      loadStatus = VehicleLoadStatus.loaded;
      errorMessage = null;
      _notifyVehicleListeners();
    } on ApiException catch (error) {
      await _setLoadError(error);
    } on TokenStorageException {
      loadStatus = VehicleLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Vehicle information cannot be loaded.';
      _notifyVehicleListeners();
    } on ApiContractException {
      loadStatus = VehicleLoadStatus.failed;
      errorMessage = 'The vehicle response was not understood. Please retry.';
      _notifyVehicleListeners();
    } finally {
      _loading = false;
    }
  }

  Future<void> retry() => load();
}
