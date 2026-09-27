part of 'history_controller.dart';

extension HistoryControllerProofPhoto on HistoryController {
  Future<void> loadDetailProofPhoto(
    String proofId, {
    bool force = false,
  }) async {
    final normalizedProofId = proofId.trim();
    if (normalizedProofId.isEmpty) return;
    if (detailProofPhotoStatus == ProofPhotoLoadStatus.loading ||
        (!force &&
            detailProofId == normalizedProofId &&
            detailProofPhotoStatus == ProofPhotoLoadStatus.loaded)) {
      return;
    }

    final epoch = ++_detailProofPhotoEpoch;
    detailProofId = normalizedProofId;
    detailProofPhoto = null;
    detailProofPhotoStatus = ProofPhotoLoadStatus.loading;
    detailProofPhotoError = null;
    _notifyHistoryListeners();
    try {
      final photo = await historyRepository.fetchProofPhoto(normalizedProofId);
      if (epoch != _detailProofPhotoEpoch ||
          detailProofId != normalizedProofId) {
        return;
      }
      detailProofPhoto = photo;
      detailProofPhotoStatus = ProofPhotoLoadStatus.loaded;
      _notifyHistoryListeners();
    } on ApiException catch (error) {
      if (epoch != _detailProofPhotoEpoch) return;
      detailProofPhoto = null;
      detailProofPhotoStatus = _proofPhotoStateFor(error);
      detailProofPhotoError = _proofPhotoMessageFor(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      _notifyHistoryListeners();
      if (error.statusCode == 401) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      if (epoch != _detailProofPhotoEpoch) return;
      detailProofPhoto = null;
      detailProofPhotoStatus = ProofPhotoLoadStatus.secureStorageFailure;
      detailProofPhotoError = 'Secure session storage is unavailable. The private photo cannot be loaded.';
      _notifyHistoryListeners();
    } on ApiContractException {
      if (epoch != _detailProofPhotoEpoch) return;
      detailProofPhoto = null;
      detailProofPhotoStatus = ProofPhotoLoadStatus.failed;
      detailProofPhotoError = 'The private photo response was not a supported JPEG, PNG, or WebP image.';
      _notifyHistoryListeners();
    }
  }

  void _clearDetailProofPhoto({required bool notify}) {
    _detailProofPhotoEpoch++;
    detailProofPhoto = null;
    detailProofId = null;
    detailProofPhotoStatus = ProofPhotoLoadStatus.idle;
    detailProofPhotoError = null;
    if (notify) _notifyHistoryListeners();
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
