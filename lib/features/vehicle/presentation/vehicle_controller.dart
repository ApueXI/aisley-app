import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle_models.dart';

typedef VehicleAuthFailureHandler = Future<void> Function(ApiException error);

enum VehicleLoadStatus {
  idle,
  loading,
  loaded,
  missing,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

enum VehicleActionStatus {
  idle,
  saving,
  saved,
  uploading,
  uploaded,
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

enum VehicleDocumentPreviewStatus {
  idle,
  loading,
  available,
  missing,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  rateLimited,
  failed,
  secureStorageFailure,
}

class VehicleController extends ChangeNotifier {
  VehicleController({required this.vehicleRepository, this.onAuthFailure});

  final VehicleRepository vehicleRepository;
  final VehicleAuthFailureHandler? onAuthFailure;

  VehicleLoadStatus loadStatus = VehicleLoadStatus.idle;
  CourierVehicle? vehicle;
  String? errorMessage;
  Duration? retryAfter;

  VehicleActionStatus updateStatus = VehicleActionStatus.idle;
  String? updateErrorMessage;
  String? updateSuccessMessage;
  Map<String, List<String>> updateFieldErrors = const <String, List<String>>{};

  final Map<VehicleDocumentKind, VehicleActionStatus> _documentStatuses =
      <VehicleDocumentKind, VehicleActionStatus>{};
  final Map<VehicleDocumentKind, String?> _documentErrors =
      <VehicleDocumentKind, String?>{};
  final Map<VehicleDocumentKind, String?> _documentSuccessMessages =
      <VehicleDocumentKind, String?>{};
  final Map<VehicleDocumentKind, Map<String, List<String>>>
  _documentFieldErrors = <VehicleDocumentKind, Map<String, List<String>>>{};
  final Map<VehicleDocumentKind, VehicleDocumentPreviewStatus>
  _documentPreviewStatuses =
      <VehicleDocumentKind, VehicleDocumentPreviewStatus>{};
  final Map<VehicleDocumentKind, VehicleDocumentData?> _documentPreviews =
      <VehicleDocumentKind, VehicleDocumentData?>{};
  final Map<VehicleDocumentKind, String?> _documentPreviewErrors =
      <VehicleDocumentKind, String?>{};

  _PendingVehicleUpdate? _pendingUpdate;
  final Map<VehicleDocumentKind, _PendingDocumentUpload> _pendingDocuments =
      <VehicleDocumentKind, _PendingDocumentUpload>{};
  Timer? _retryTimer;
  bool _loading = false;
  bool _authFailureNotified = false;

  bool get canRetryRateLimit => _retryTimer == null;

  bool get isBusy =>
      updateStatus == VehicleActionStatus.saving ||
      VehicleDocumentKind.values.any(
        (kind) => documentActionStatus(kind) == VehicleActionStatus.uploading,
      );

  bool get hasPendingUpdate => _pendingUpdate != null;

  VehicleActionStatus documentActionStatus(VehicleDocumentKind kind) {
    return _documentStatuses[kind] ?? VehicleActionStatus.idle;
  }

  String? documentActionError(VehicleDocumentKind kind) =>
      _documentErrors[kind];

  String? documentActionSuccessMessage(VehicleDocumentKind kind) =>
      _documentSuccessMessages[kind];

  String? documentFieldError(VehicleDocumentKind kind, String field) {
    final messages = _documentFieldErrors[kind]?[field];
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages.join(' ');
  }

  VehicleDocumentPreviewStatus documentPreviewStatus(VehicleDocumentKind kind) {
    return _documentPreviewStatuses[kind] ?? VehicleDocumentPreviewStatus.idle;
  }

  VehicleDocumentData? documentPreview(VehicleDocumentKind kind) =>
      _documentPreviews[kind];

  String? documentPreviewError(VehicleDocumentKind kind) =>
      _documentPreviewErrors[kind];

  Future<void> load() async {
    if (_loading || !canRetryRateLimit) {
      return;
    }
    _loading = true;
    _authFailureNotified = false;
    retryAfter = null;
    loadStatus = VehicleLoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedVehicle = await vehicleRepository.fetchVehicle();
      vehicle = loadedVehicle;
      loadStatus = VehicleLoadStatus.loaded;
      errorMessage = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setLoadError(error);
    } on TokenStorageException {
      loadStatus = VehicleLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Vehicle information cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      loadStatus = VehicleLoadStatus.failed;
      errorMessage = 'The vehicle response was not understood. Please retry.';
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

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
            idempotencyKey: _newUuid(),
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
    notifyListeners();

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
      notifyListeners();
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
      notifyListeners();
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
            idempotencyKey: _newUuid(),
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
    notifyListeners();

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
      notifyListeners();
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
      notifyListeners();
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
    notifyListeners();

    try {
      final loadedDocument = await vehicleRepository.fetchDocument(kind);
      if (loadedDocument.bytes.isEmpty) {
        throw ApiContractException('vehicle.documents.${kind.value}.body');
      }
      _documentPreviews[kind] = loadedDocument;
      _documentPreviewStatuses[kind] = VehicleDocumentPreviewStatus.available;
      _documentPreviewErrors[kind] = null;
      notifyListeners();
    } on ApiException catch (error) {
      await _setDocumentPreviewError(kind, error);
    } on TokenStorageException {
      _documentPreviewStatuses[kind] =
          VehicleDocumentPreviewStatus.secureStorageFailure;
      _documentPreviewErrors[kind] = 'Secure session storage is unavailable. This document cannot be loaded.';
      notifyListeners();
    } on ApiContractException {
      _documentPreviewStatuses[kind] = VehicleDocumentPreviewStatus.failed;
      _documentPreviewErrors[kind] =
          'The private ${kind.shortLabel} response was not understood. Please retry.';
      notifyListeners();
    }
  }

  Future<void> retry() => load();

  void clear() {
    _retryTimer?.cancel();
    _retryTimer = null;
    vehicle = null;
    loadStatus = VehicleLoadStatus.idle;
    errorMessage = null;
    retryAfter = null;
    updateStatus = VehicleActionStatus.idle;
    updateErrorMessage = null;
    updateSuccessMessage = null;
    updateFieldErrors = const <String, List<String>>{};
    _pendingUpdate = null;
    _pendingDocuments.clear();
    _documentStatuses.clear();
    _documentErrors.clear();
    _documentSuccessMessages.clear();
    _documentFieldErrors.clear();
    _documentPreviewStatuses.clear();
    _documentPreviews.clear();
    _documentPreviewErrors.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _setLoadError(ApiException error) async {
    loadStatus = _loadStateFor(error);
    errorMessage = _messageForError(error, subject: 'vehicle information');
    if (loadStatus == VehicleLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setUpdateError(ApiException error) async {
    updateStatus = _actionStateFor(error);
    updateErrorMessage = _messageForError(error, subject: 'vehicle details');
    updateSuccessMessage = null;
    updateFieldErrors = error.fieldErrors;
    if (updateStatus == VehicleActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 409) {
      await _refreshAfterConflict();
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setDocumentError(
    VehicleDocumentKind kind,
    ApiException error,
  ) async {
    _documentStatuses[kind] = _actionStateFor(error);
    _documentErrors[kind] = _messageForError(
      error,
      subject: '${kind.shortLabel} document',
    );
    _documentSuccessMessages[kind] = null;
    _documentFieldErrors[kind] = error.fieldErrors;
    if (_documentStatuses[kind] == VehicleActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 409) {
      await _refreshAfterConflict();
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setDocumentPreviewError(
    VehicleDocumentKind kind,
    ApiException error,
  ) async {
    _documentPreviewStatuses[kind] = _previewStateFor(error);
    _documentPreviewErrors[kind] = _messageForError(
      error,
      subject: 'private ${kind.shortLabel} document',
    );
    if (_documentPreviewStatuses[kind] ==
        VehicleDocumentPreviewStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    notifyListeners();
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _reconcileUncertainUpdate(ApiException error) async {
    try {
      final refreshedVehicle = await vehicleRepository.fetchVehicle();
      vehicle = refreshedVehicle;
      updateStatus = _actionStateFor(error);
      updateErrorMessage = 'The save result was uncertain. We refreshed your vehicle; review the values and retry the same save if needed.';
      updateSuccessMessage = null;
      updateFieldErrors = const <String, List<String>>{};
      notifyListeners();
    } on ApiException catch (refreshError) {
      await _setUpdateError(refreshError);
    } on TokenStorageException {
      updateStatus = VehicleActionStatus.secureStorageFailure;
      updateErrorMessage = 'Secure session storage is unavailable. The save result is uncertain.';
      notifyListeners();
    } on ApiContractException {
      updateStatus = VehicleActionStatus.failed;
      updateErrorMessage = 'The save result was uncertain and could not be reconciled. Refresh before retrying.';
      notifyListeners();
    }
  }

  Future<void> _reconcileUncertainDocument(
    VehicleDocumentKind kind,
    ApiException error,
  ) async {
    try {
      final refreshedVehicle = await vehicleRepository.fetchVehicle();
      vehicle = refreshedVehicle;
      _documentStatuses[kind] = _actionStateFor(error);
      _documentErrors[kind] =
          'The ${kind.shortLabel} upload result was uncertain. We refreshed the vehicle; review the current document and retry if needed.';
      _documentSuccessMessages[kind] = null;
      _documentFieldErrors[kind] = const <String, List<String>>{};
      notifyListeners();
    } on ApiException catch (refreshError) {
      await _setDocumentError(kind, refreshError);
    } on TokenStorageException {
      _documentStatuses[kind] = VehicleActionStatus.secureStorageFailure;
      _documentErrors[kind] = 'Secure session storage is unavailable. The upload result is uncertain.';
      notifyListeners();
    } on ApiContractException {
      _documentStatuses[kind] = VehicleActionStatus.failed;
      _documentErrors[kind] = 'The upload result was uncertain and could not be reconciled. Refresh before retrying.';
      notifyListeners();
    }
  }

  Future<void> _refreshAfterConflict() async {
    try {
      final refreshedVehicle = await vehicleRepository.fetchVehicle();
      vehicle = refreshedVehicle;
      notifyListeners();
    } on ApiException catch (error) {
      loadStatus = _loadStateFor(error);
      errorMessage = _messageForError(error, subject: 'vehicle information');
      notifyListeners();
    } on TokenStorageException {
      loadStatus = VehicleLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Refresh could not be completed.';
      notifyListeners();
    } on ApiContractException {
      loadStatus = VehicleLoadStatus.failed;
      errorMessage =
          'The refreshed vehicle response was not understood. Please retry.';
      notifyListeners();
    }
  }

  Future<void> _notifyAuthFailure(ApiException error) async {
    if (_authFailureNotified) {
      return;
    }
    _authFailureNotified = true;
    await onAuthFailure?.call(error);
  }

  void _setLocalUpdateError(String message) {
    updateStatus = VehicleActionStatus.validationError;
    updateErrorMessage = message;
    updateSuccessMessage = null;
    notifyListeners();
  }

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
      notifyListeners();
    });
    retryAfter = delay;
  }

  static bool _isDefinitiveMutationError(ApiException error) {
    return error.statusCode == 404 ||
        error.statusCode == 409 ||
        error.statusCode == 422;
  }

  static bool _sameSelection(
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

  static bool _mapsEqual(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) {
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

class _PendingVehicleUpdate {
  const _PendingVehicleUpdate({
    required this.changes,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final Map<String, Object?> changes;
  final int expectedRevision;
  final String idempotencyKey;
}

class _PendingDocumentUpload {
  const _PendingDocumentUpload({
    required this.selection,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final VehicleDocumentSelection selection;
  final int expectedRevision;
  final String idempotencyKey;
}
