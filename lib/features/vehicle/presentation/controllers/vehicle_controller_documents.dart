part of 'vehicle_controller.dart';

extension VehicleControllerDocuments on VehicleController {
  Future<bool> uploadDocument(
    VehicleDocumentKind kind,
    VehicleDocumentSelection selection, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    final current = vehicle;
    if (current == null || !canRetryRateLimit) {
      return false;
    }
    if (documentActionStatus(kind) == VehicleActionStatus.uploading) {
      return false;
    }

    final existing = _pendingDocuments[kind];
    final attempt =
        existing != null && _sameSelection(existing.selection, selection)
        ? existing
        : _PendingDocumentUpload(
            selection: selection,
            expectedRevision: current.revision,
            idempotencyKey: VehicleController._newUuid(),
          );
    _pendingDocuments[kind] = attempt;
    return _performDocumentUpload(kind, attempt, onCancel: onCancel);
  }

  Future<bool> retryDocument(VehicleDocumentKind kind) async {
    final attempt = _pendingDocuments[kind];
    if (attempt == null ||
        documentActionStatus(kind) == VehicleActionStatus.uploading) {
      return false;
    }
    return _performDocumentUpload(kind, attempt);
  }

  Future<bool> _performDocumentUpload(
    VehicleDocumentKind kind,
    _PendingDocumentUpload attempt, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    _documentStatuses[kind] = VehicleActionStatus.uploading;
    _documentErrors[kind] = null;
    _documentSuccessMessages[kind] = null;
    _documentFieldErrors[kind] = const <String, List<String>>{};
    _notifyVehicleListeners();

    try {
      final updatedVehicle = await vehicleRepository.uploadDocument(
        kind: kind,
        selection: attempt.selection,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
        onCancel: onCancel,
      );
      vehicle = updatedVehicle;
      _pendingDocuments.remove(kind);
      _documentStatuses[kind] = VehicleActionStatus.uploaded;
      _documentSuccessMessages[kind] = '${kind.shortLabel} was uploaded.';
      _documentPreviews.remove(kind);
      _documentPreviewStatuses[kind] = VehicleDocumentPreviewStatus.idle;
      _documentPreviewErrors[kind] = null;
      _notifyVehicleListeners();
      return true;
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        await _reconcileUncertainDocument(kind, error);
      } else {
        if (_isDefinitiveMutationError(error)) {
          _pendingDocuments.remove(kind);
        }
        await _setDocumentError(kind, error);
      }
    } on TokenStorageException {
      _documentStatuses[kind] = VehicleActionStatus.secureStorageFailure;
      _documentErrors[kind] =
          'Secure session storage is unavailable. The ${kind.shortLabel} was not changed.';
      _documentSuccessMessages[kind] = null;
      _notifyVehicleListeners();
    } on ApiContractException {
      await _reconcileUncertainDocument(
        kind,
        const ApiException.network(
          'The upload response was not understood.',
          networkFailure: ApiNetworkFailure.timeout,
        ),
      );
    }
    return false;
  }

  Future<void> loadDocument(VehicleDocumentKind kind) async {
    _documentPreviewStatuses[kind] = VehicleDocumentPreviewStatus.loading;
    _documentPreviewErrors[kind] = null;
    _notifyVehicleListeners();

    try {
      final loadedDocument = await vehicleRepository.fetchDocument(kind);
      if (loadedDocument.bytes.isEmpty) {
        throw ApiContractException('vehicle.documents.${kind.value}.body');
      }
      _documentPreviews[kind] = loadedDocument;
      _documentPreviewStatuses[kind] = VehicleDocumentPreviewStatus.available;
      _documentPreviewErrors[kind] = null;
      _notifyVehicleListeners();
    } on ApiException catch (error) {
      await _setDocumentPreviewError(kind, error);
    } on TokenStorageException {
      _documentPreviewStatuses[kind] =
          VehicleDocumentPreviewStatus.secureStorageFailure;
      _documentPreviewErrors[kind] = 'Secure session storage is unavailable. This document cannot be loaded.';
      _notifyVehicleListeners();
    } on ApiContractException {
      _documentPreviewStatuses[kind] = VehicleDocumentPreviewStatus.failed;
      _documentPreviewErrors[kind] =
          'The private ${kind.shortLabel} response was not understood. Please retry.';
      _notifyVehicleListeners();
    }
  }
}
