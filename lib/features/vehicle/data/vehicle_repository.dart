import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/networking/multipart_file_selection.dart';
import '../domain/vehicle_models.dart';

abstract interface class VehicleRepository {
  Future<CourierVehicle> fetchVehicle();

  Future<CourierVehicle> updateVehicle({
    required Map<String, Object?> changes,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<CourierVehicle> uploadDocument({
    required VehicleDocumentKind kind,
    required VehicleDocumentSelection selection,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  });

  Future<VehicleDocumentData> fetchDocument(VehicleDocumentKind kind);
}

class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository({required this._client});

  final ApiClient _client;

  @override
  Future<CourierVehicle> fetchVehicle() async {
    final response = await _client.get('/courier/vehicle', authenticated: true);
    return _vehicleFromResponse(response.body, 'vehicle.response');
  }

  @override
  Future<CourierVehicle> updateVehicle({
    required Map<String, Object?> changes,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    const allowedFields = <String>{
      'vehicle_type',
      'plate_number',
      'make',
      'model',
    };
    if (changes.keys.any((key) => !allowedFields.contains(key))) {
      throw ArgumentError.value(
        changes.keys,
        'changes',
        'contains a field that is not editable by the Courier',
      );
    }
    final body = <String, Object?>{
      ...changes,
      'expected_revision': expectedRevision,
    };
    final response = await _client.patchJson(
      '/courier/vehicle',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: body,
    );
    return _vehicleFromResponse(response.body, 'vehicle.update');
  }

  @override
  Future<CourierVehicle> uploadDocument({
    required VehicleDocumentKind kind,
    required VehicleDocumentSelection selection,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    final response = await _client.postMultipart(
      '/courier/vehicle/documents/${kind.value}',
      fields: <String, String>{'expected_revision': '$expectedRevision'},
      files: <String, MultipartFileSelection>{
        'file': MultipartFileSelection(
          path: selection.path,
          fileName: selection.fileName,
          bytes: selection.bytes,
        ),
      },
      authenticated: true,
      requestHeaders: <String, String>{'Idempotency-Key': idempotencyKey},
      onCancel: onCancel,
    );
    return _vehicleFromResponse(response.body, 'vehicle.document.upload');
  }

  @override
  Future<VehicleDocumentData> fetchDocument(VehicleDocumentKind kind) async {
    final response = await _client.get(
      '/courier/vehicle/documents/${kind.value}',
      authenticated: true,
      headers: const <String, String>{
        'Accept': 'image/jpeg, image/png, image/webp',
      },
    );
    final contentType = _contentType(response.headers['content-type']);
    if (contentType == null || !_allowedImageTypes.contains(contentType)) {
      throw ApiContractException(
        'vehicle.documents.${kind.value}.content_type',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw ApiContractException('vehicle.documents.${kind.value}.body');
    }
    return VehicleDocumentData(
      bytes: response.bodyBytes,
      contentType: contentType,
    );
  }
}

const _allowedImageTypes = <String>{'image/jpeg', 'image/png', 'image/webp'};

String? _contentType(String? value) {
  final contentType = value?.split(';').first.trim().toLowerCase();
  return contentType == null || contentType.isEmpty ? null : contentType;
}

CourierVehicle _vehicleFromResponse(String body, String field) {
  if (body.trim().isEmpty) {
    throw ApiContractException(field);
  }
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw ApiContractException(field);
    }
    return CourierVehicle.fromResponse(Map<String, dynamic>.from(decoded));
  } on FormatException {
    throw ApiContractException(field);
  }
}
