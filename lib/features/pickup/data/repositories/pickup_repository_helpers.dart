part of '../pickup_repository.dart';

PickupTask _taskFromData(
  Map<String, dynamic> payload,
  PickupTaskLeg defaultLeg,
) {
  final data = payload['data'];
  if (data is! Map) {
    throw const ApiContractException('pickup.task.data');
  }
  return PickupTask.fromJson(
    Map<String, dynamic>.from(data),
    defaultLeg: defaultLeg,
  );
}

String _pathSegment(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'value', 'must not be empty');
  }
  return Uri.encodeComponent(normalized);
}

Map<String, dynamic> _decodeObject(String body, String field) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } on FormatException {
    // Fall through to the typed contract error below.
  }
  throw ApiContractException(field);
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = value is int ? value : int.tryParse(value.toString());
  if (parsed == null) {
    throw const ApiContractException('pickup.meta.integer');
  }
  return parsed;
}
