import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle_models.dart';

part 'vehicle_controller_reads.dart';
part 'vehicle_controller_updates.dart';
part 'vehicle_controller_documents.dart';
part 'vehicle_controller_errors.dart';
part 'vehicle_controller_validation.dart';
part 'vehicle_controller_attempts.dart';

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

  void _notifyVehicleListeners() => notifyListeners();

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
