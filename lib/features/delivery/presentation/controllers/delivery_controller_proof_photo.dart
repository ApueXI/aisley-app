part of 'delivery_controller.dart';

extension DeliveryControllerProofPhoto on DeliveryController {
  Future<void> loadProofPhoto(String proofId, {bool force = false}) async {
    final normalizedProofId = proofId.trim();
    if (normalizedProofId.isEmpty) return;
    final currentStatus = proofPhotoStatuses[normalizedProofId];
    if (currentStatus == ProofPhotoLoadStatus.loading ||
        (!force && currentStatus == ProofPhotoLoadStatus.loaded)) {
      return;
    }

    final epoch = ++_proofPhotoEpochCounter;
    _proofPhotoEpochs[normalizedProofId] = epoch;
    proofPhotoStatuses[normalizedProofId] = ProofPhotoLoadStatus.loading;
    proofPhotoErrors[normalizedProofId] = null;
    _notifyDeliveryListeners();
    try {
      final photo = await deliveryRepository.fetchProofPhoto(normalizedProofId);
      if (_proofPhotoEpochs[normalizedProofId] != epoch) return;
      proofPhotos[normalizedProofId] = photo;
      proofPhotoStatuses[normalizedProofId] = ProofPhotoLoadStatus.loaded;
      proofPhotoErrors[normalizedProofId] = null;
      _notifyDeliveryListeners();
    } on ApiException catch (error) {
      if (_proofPhotoEpochs[normalizedProofId] != epoch) return;
      proofPhotos.remove(normalizedProofId);
      proofPhotoStatuses[normalizedProofId] = _proofPhotoStateFor(error);
      proofPhotoErrors[normalizedProofId] = _proofPhotoMessageFor(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      _notifyDeliveryListeners();
      if (error.statusCode == 401) {
        clearAllProofPhotos(notify: false);
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      if (_proofPhotoEpochs[normalizedProofId] != epoch) return;
      proofPhotos.remove(normalizedProofId);
      proofPhotoStatuses[normalizedProofId] =
          ProofPhotoLoadStatus.secureStorageFailure;
      proofPhotoErrors[normalizedProofId] = 'Secure session storage is unavailable. The private photo cannot be loaded.';
      _notifyDeliveryListeners();
    } on ApiContractException {
      if (_proofPhotoEpochs[normalizedProofId] != epoch) return;
      proofPhotos.remove(normalizedProofId);
      proofPhotoStatuses[normalizedProofId] = ProofPhotoLoadStatus.failed;
      proofPhotoErrors[normalizedProofId] = 'The private photo response was not a supported JPEG, PNG, or WebP image.';
      _notifyDeliveryListeners();
    }
  }

  void clearProofPhoto(String proofId) {
    final normalizedProofId = proofId.trim();
    if (normalizedProofId.isEmpty) return;
    _proofPhotoEpochCounter++;
    _proofPhotoEpochs.remove(normalizedProofId);
    proofPhotos.remove(normalizedProofId);
    proofPhotoStatuses.remove(normalizedProofId);
    proofPhotoErrors.remove(normalizedProofId);
    _notifyDeliveryListeners();
  }

  void clearProofPhotosForTask(String taskId, {bool notify = true}) {
    final proofIds = <String>{
      ?proofs[taskId]?.proofId,
      ?completions[taskId]?.evidenceId,
    };
    _proofPhotoEpochCounter++;
    for (final proofId in proofIds) {
      _proofPhotoEpochs.remove(proofId);
      proofPhotos.remove(proofId);
      proofPhotoStatuses.remove(proofId);
      proofPhotoErrors.remove(proofId);
    }
    if (notify && proofIds.isNotEmpty) _notifyDeliveryListeners();
  }

  void clearAllProofPhotos({bool notify = true}) {
    final proofIds = <String>{
      ..._proofPhotoEpochs.keys,
      ...proofPhotos.keys,
      ...proofPhotoStatuses.keys,
      ...proofPhotoErrors.keys,
    };
    _proofPhotoEpochCounter++;
    _proofPhotoEpochs.clear();
    proofPhotos.clear();
    proofPhotoStatuses.clear();
    proofPhotoErrors.clear();
    if (notify && proofIds.isNotEmpty) _notifyDeliveryListeners();
  }

  ProofPhotoLoadStatus _proofPhotoStateFor(ApiException error) {
    if (error.statusCode == 401) return ProofPhotoLoadStatus.unauthorized;
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? ProofPhotoLoadStatus.consentRequired
          : ProofPhotoLoadStatus.forbidden;
    }
    if (error.statusCode == 404) return ProofPhotoLoadStatus.unavailable;
    if (error.statusCode == 429) return ProofPhotoLoadStatus.rateLimited;
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? ProofPhotoLoadStatus.timeout
          : ProofPhotoLoadStatus.offline;
    }
    return ProofPhotoLoadStatus.failed;
  }

  String _proofPhotoMessageFor(ApiException error) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current policies before reviewing this private photo.';
    }
    if (error.statusCode == 401) {
      return 'Your Courier session is no longer valid.';
    }
    if (error.statusCode == 403) {
      return 'This private photo is not available to your Courier account.';
    }
    if (error.statusCode == 404) {
      return 'The private proof photo is unavailable.';
    }
    if (error.statusCode == 429) {
      return 'Too many photo requests. Wait before trying again.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'The private photo request timed out. Retry when the service is reachable.'
          : 'The private photo could not be loaded offline. Reconnect and retry.';
    }
    return 'The private proof photo could not be loaded. Please retry.';
  }
}
