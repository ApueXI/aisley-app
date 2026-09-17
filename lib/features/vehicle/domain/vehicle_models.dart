import 'dart:typed_data';

import '../../../core/networking/api_contract_exception.dart';

enum VehicleDocumentKind {
  officialReceipt('official_receipt', 'Official Receipt', 'OR'),
  certificateOfRegistration(
    'certificate_of_registration',
    'Certificate of Registration',
    'CR',
  );

  const VehicleDocumentKind(this.value, this.label, this.shortLabel);

  final String value;
  final String label;
  final String shortLabel;
}

class VehicleDocumentReference {
  const VehicleDocumentReference({required this.id, required this.url});

  final String id;
  final String url;
}

class VehicleDocumentData {
  const VehicleDocumentData({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class VehicleDocumentSelection {
  const VehicleDocumentSelection({
    required this.path,
    required this.fileName,
    required this.bytes,
  });

  /// The temporary local path used only for the multipart upload.
  final String path;
  final String fileName;
  final Uint8List bytes;

  int get sizeInBytes => bytes.length;
}

class CourierVehicle {
  const CourierVehicle({
    required this.id,
    required this.vehicleType,
    required this.plateNumber,
    required this.revision,
    this.make,
    this.model,
    this.officialReceipt,
    this.certificateOfRegistration,
  });

  final String id;
  final String vehicleType;
  final String plateNumber;
  final String? make;
  final String? model;
  final int revision;
  final VehicleDocumentReference? officialReceipt;
  final VehicleDocumentReference? certificateOfRegistration;

  factory CourierVehicle.fromResponse(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const ApiContractException('vehicle.data');
    }
    return CourierVehicle.fromJson(Map<String, dynamic>.from(rawData));
  }

  factory CourierVehicle.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id'], 'vehicle.id');
    final vehicleType = _requiredString(
      json['vehicle_type'],
      'vehicle.vehicle_type',
    );
    if (!const <String>{'motorcycle', 'car', 'van'}.contains(vehicleType)) {
      throw const ApiContractException('vehicle.vehicle_type');
    }
    return CourierVehicle(
      id: id,
      vehicleType: vehicleType,
      plateNumber: _requiredString(
        json['plate_number'],
        'vehicle.plate_number',
      ),
      make: _nullableString(json['make'], 'vehicle.make'),
      model: _nullableString(json['model'], 'vehicle.model'),
      revision: _requiredInt(json['revision'], 'vehicle.revision'),
      officialReceipt: _documentFrom(
        json['official_receipt'],
        'vehicle.official_receipt',
      ),
      certificateOfRegistration: _documentFrom(
        json['certificate_of_registration'],
        'vehicle.certificate_of_registration',
      ),
    );
  }

  VehicleDocumentReference? document(VehicleDocumentKind kind) {
    return switch (kind) {
      VehicleDocumentKind.officialReceipt => officialReceipt,
      VehicleDocumentKind.certificateOfRegistration =>
        certificateOfRegistration,
    };
  }
}

VehicleDocumentReference? _documentFrom(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw ApiContractException(field);
  }
  final source = Map<String, dynamic>.from(value);
  return VehicleDocumentReference(
    id: _requiredString(source['id'], '$field.id'),
    url: _requiredString(source['url'], '$field.url'),
  );
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value.trim();
}

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Object? value, String field) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) {
    throw ApiContractException(field);
  }
  return parsed;
}
