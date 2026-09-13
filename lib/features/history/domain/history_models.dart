import '../../../core/networking/api_contract_exception.dart';
import '../../pickup/domain/pickup_models.dart';

class DeliveryHistoryItem {
  const DeliveryHistoryItem({
    required this.taskId,
    required this.status,
    this.order,
    this.deliveredAt,
    this.pickupArea,
    this.destinationArea,
    this.parcelReference,
    this.itemCount,
    this.evidenceStatus,
    this.completionStatus,
    this.evidenceId,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.items = const <HistoryItemSnapshot>[],
  });

  final String taskId;
  final String status;
  final PickupOrderReference? order;
  final DateTime? deliveredAt;
  final PickupLocation? pickupArea;
  final PickupLocation? destinationArea;
  final String? parcelReference;
  final int? itemCount;
  final String? evidenceStatus;
  final String? completionStatus;
  final String? evidenceId;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final List<HistoryItemSnapshot> items;

  factory DeliveryHistoryItem.fromJson(Map<String, dynamic> json) {
    final taskId = _requiredString(
      json['task_id'] ?? json['id'],
      'history.task_id',
    );
    final leg = _requiredString(json['leg'], 'history.leg');
    if (leg != 'final_mile') {
      throw const ApiContractException('history.final_mile_leg');
    }
    final status = _requiredString(json['status'], 'history.status');
    if (status != 'delivered') {
      throw const ApiContractException('history.delivered_status');
    }
    final deliveredAt = _nullableDateTime(json['delivered_at']);
    if (deliveredAt == null) {
      throw const ApiContractException('history.delivered_at');
    }
    final rawParcel = json['parcel'];
    final parcel = rawParcel is Map
        ? Map<String, dynamic>.from(rawParcel)
        : const <String, dynamic>{};
    final rawItems = json['items'];
    final items = <HistoryItemSnapshot>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) {
          throw const ApiContractException('history.item');
        }
        items.add(
          HistoryItemSnapshot.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return DeliveryHistoryItem(
      taskId: taskId,
      status: status,
      order: json['order'] is Map
          ? PickupOrderReference.fromJson(json['order'])
          : null,
      deliveredAt: deliveredAt,
      pickupArea: _location(json['pickup_area']),
      destinationArea: _location(json['destination_area']),
      parcelReference: _nullableString(
        parcel['reference'] ?? json['parcel_reference'],
      ),
      itemCount: _nullableInt(parcel['item_count'] ?? json['item_count']),
      evidenceStatus: _nullableString(json['evidence_status']),
      completionStatus: _nullableString(json['completion_status']),
      evidenceId: _nullableString(json['evidence_id']),
      distanceKm: _nullableDouble(json['distance_km']),
      estimatedDurationMinutes: _nullableInt(
        json['estimated_duration_minutes'],
      ),
      items: items,
    );
  }
}

class HistoryItemSnapshot {
  const HistoryItemSnapshot({this.name, this.quantity});

  final String? name;
  final int? quantity;

  factory HistoryItemSnapshot.fromJson(Map<String, dynamic> json) {
    return HistoryItemSnapshot(
      name: _nullableString(json['name'] ?? json['title']),
      quantity: _nullableInt(json['quantity']),
    );
  }
}

class DeliveryHistoryPage {
  const DeliveryHistoryPage({
    required this.items,
    this.hasMore = false,
    this.nextCursor,
  });

  final List<DeliveryHistoryItem> items;
  final bool hasMore;
  final String? nextCursor;
}

PickupLocation? _location(Object? value) {
  return value is Map ? PickupLocation.fromJson(value) : null;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value.trim();
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const ApiContractException('history.value');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  final parsed = value is int ? value : int.tryParse(value.toString());
  if (parsed == null) {
    throw const ApiContractException('history.integer');
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
    throw const ApiContractException('history.number');
  }
  return parsed;
}

DateTime? _nullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const ApiContractException('history.timestamp');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const ApiContractException('history.timestamp');
  }
  return parsed.toUtc();
}
