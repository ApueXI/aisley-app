part of 'vehicle_controller.dart';

extension VehicleControllerUpdates on VehicleController {
  Future<bool> updateVehicle({required Map<String, Object?> changes}) async {
    final current = vehicle;
    if (current == null || changes.isEmpty || !canRetryRateLimit) {
      return false;
    }
    if (updateStatus == VehicleActionStatus.saving) {
      return false;
    }

    final normalized = _normalizeChanges(changes);
    if (normalized == null || normalized.isEmpty) {
      _setLocalUpdateError('There are no supported vehicle changes to save.');
      return false;
    }

    final pending = _pendingUpdate;
    final attempt =
        pending != null &&
            pending.expectedRevision == current.revision &&
            _mapsEqual(pending.changes, normalized)
        ? pending
        : _PendingVehicleUpdate(
            changes: normalized,
            expectedRevision: current.revision,
            idempotencyKey: VehicleController._newUuid(),
          );
    _pendingUpdate = attempt;
    return _performUpdate(attempt);
  }

  Future<bool> retryUpdate() async {
    final attempt = _pendingUpdate;
    if (attempt == null || updateStatus == VehicleActionStatus.saving) {
      return false;
    }
    return _performUpdate(attempt);
  }

  Future<bool> _performUpdate(_PendingVehicleUpdate attempt) async {
    updateStatus = VehicleActionStatus.saving;
    updateErrorMessage = null;
    updateSuccessMessage = null;
    updateFieldErrors = const <String, List<String>>{};
    _notifyVehicleListeners();

    try {
      final updatedVehicle = await vehicleRepository.updateVehicle(
        changes: attempt.changes,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
      );
      vehicle = updatedVehicle;
      _pendingUpdate = null;
      updateStatus = VehicleActionStatus.saved;
      updateSuccessMessage = 'Your vehicle details were updated.';
      _notifyVehicleListeners();
      return true;
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        await _reconcileUncertainUpdate(error);
      } else {
        if (_isDefinitiveMutationError(error)) {
          _pendingUpdate = null;
        }
        await _setUpdateError(error);
      }
    } on TokenStorageException {
      updateStatus = VehicleActionStatus.secureStorageFailure;
      updateErrorMessage = 'Secure session storage is unavailable. Your vehicle was not changed.';
      updateSuccessMessage = null;
      _notifyVehicleListeners();
    } on ApiContractException {
      await _reconcileUncertainUpdate(
        const ApiException.network(
          'The save response was not understood.',
          networkFailure: ApiNetworkFailure.timeout,
        ),
      );
    }
    return false;
  }
}
