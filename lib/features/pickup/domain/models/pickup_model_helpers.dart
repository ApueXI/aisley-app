part of '../pickup_models.dart';

PickupOrderReference? _orderFromFlatFields(Map<String, dynamic> json) {
  final id = _nullableString(json['order_id']);
  final reference = _nullableString(json['order_reference']);
  return id == null && reference == null
      ? null
      : PickupOrderReference(id: id, reference: reference);
}

PickupWaybillReference? _waybillFromFlatFields(Map<String, dynamic> json) {
  final id = _nullableString(json['waybill_id']);
  final reference = _nullableString(json['waybill_reference']);
  return id == null && reference == null
      ? null
      : PickupWaybillReference(id: id, reference: reference);
}

String? _addressSummary(Map<String, dynamic> json) {
  final direct = _nullableString(json['address_summary']);
  if (direct != null) {
    return direct;
  }
  final address = json['address'];
  if (address is Map) {
    return _nullableString(address['summary']);
  }
  return null;
}

List<String> _stringList(Object? value, {Object? fallback}) {
  if (value is List) {
    return value
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final one = _nullableString(fallback);
  return one == null ? const <String>[] : <String>[one];
}

Map<String, dynamic>? _nullableMap(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is! Map) {
    throw ApiContractException(field);
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const ApiContractException('pickup.value');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _nullableString(json[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = value is int ? value : int.tryParse(value.toString());
  if (parsed == null) {
    throw const ApiContractException('pickup.integer');
  }
  return parsed;
}

double? _nullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (parsed == null) {
    throw const ApiContractException('pickup.number');
  }
  return parsed;
}

DateTime? _nullableUtc(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const ApiContractException('pickup.timestamp');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const ApiContractException('pickup.timestamp');
  }
  return parsed.toUtc();
}
