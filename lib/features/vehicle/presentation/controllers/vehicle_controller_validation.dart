part of 'vehicle_controller.dart';

extension VehicleControllerValidation on VehicleController {
  Map<String, Object?>? _normalizeChanges(Map<String, Object?> changes) {
    final normalized = <String, Object?>{};
    for (final entry in changes.entries) {
      if (!const <String>{
        'vehicle_type',
        'plate_number',
        'make',
        'model',
      }.contains(entry.key)) {
        return null;
      }
      if (entry.key == 'make' || entry.key == 'model') {
        if (entry.value == null) {
          normalized[entry.key] = null;
        } else if (entry.value is String) {
          final value = (entry.value as String).trim();
          normalized[entry.key] = value.isEmpty ? null : value;
        } else {
          return null;
        }
      } else if (entry.value is String &&
          (entry.value as String).trim().isNotEmpty) {
        normalized[entry.key] = (entry.value as String).trim();
      } else {
        return null;
      }
    }
    return normalized;
  }

  VehicleLoadStatus _loadStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return VehicleLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? VehicleLoadStatus.consentRequired
          : VehicleLoadStatus.forbidden;
    }
    if (error.statusCode == 404) {
      return VehicleLoadStatus.missing;
    }
    if (error.statusCode == 429) {
      return VehicleLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? VehicleLoadStatus.timeout
          : VehicleLoadStatus.offline;
    }
    return VehicleLoadStatus.failed;
  }

  VehicleActionStatus _actionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return VehicleActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? VehicleActionStatus.consentRequired
          : VehicleActionStatus.forbidden;
    }
    if (error.statusCode == 409) {
      return VehicleActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return VehicleActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return VehicleActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? VehicleActionStatus.timeout
          : VehicleActionStatus.offline;
    }
    return VehicleActionStatus.failed;
  }

  VehicleDocumentPreviewStatus _previewStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return VehicleDocumentPreviewStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? VehicleDocumentPreviewStatus.consentRequired
          : VehicleDocumentPreviewStatus.forbidden;
    }
    if (error.statusCode == 404) {
      return VehicleDocumentPreviewStatus.missing;
    }
    if (error.statusCode == 429) {
      return VehicleDocumentPreviewStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? VehicleDocumentPreviewStatus.timeout
          : VehicleDocumentPreviewStatus.offline;
    }
    return VehicleDocumentPreviewStatus.failed;
  }

  String _messageForError(ApiException error, {required String subject}) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current policy consent before managing $subject.';
    }
    if (error.statusCode == 404) {
      return 'The requested $subject is not available.';
    }
    if (error.statusCode == 409) {
      return 'The $subject changed on the server. Refresh completed; review your unsaved values and try again.';
    }
    if (error.statusCode == 422) {
      return error.message.isEmpty
          ? 'Check the highlighted fields and try again.'
          : error.message;
    }
    if (error.statusCode == 429) {
      final seconds = error.retryAfter?.inSeconds;
      return seconds == null || seconds <= 1
          ? 'Too many requests. Try again in a moment.'
          : 'Too many requests. Try again in $seconds seconds.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'The request timed out. Reconnect and retry.'
          : 'The service is unreachable. Reconnect and retry.';
    }
    if (error.statusCode == 401) {
      return 'Your Courier session is no longer valid. Please sign in again.';
    }
    if (error.statusCode == 403) {
      return error.message.isEmpty
          ? 'This action is not available to your Courier account.'
          : error.message;
    }
    return 'The $subject service could not complete the request. Please retry.';
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
      _notifyVehicleListeners();
    });
    retryAfter = delay;
  }

  bool _isDefinitiveMutationError(ApiException error) {
    return error.statusCode == 404 ||
        error.statusCode == 409 ||
        error.statusCode == 422;
  }

  bool _sameSelection(
    VehicleDocumentSelection first,
    VehicleDocumentSelection second,
  ) {
    if (first.path != second.path ||
        first.fileName != second.fileName ||
        first.bytes.length != second.bytes.length) {
      return false;
    }
    for (var index = 0; index < first.bytes.length; index += 1) {
      if (first.bytes[index] != second.bytes[index]) {
        return false;
      }
    }
    return true;
  }

  bool _mapsEqual(Map<String, Object?> first, Map<String, Object?> second) {
    if (first.length != second.length) {
      return false;
    }
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
