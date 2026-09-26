import '../../../core/networking/api_contract_exception.dart';

enum FinalMileBatchStatus {
  offered('offered'),
  accepted('accepted'),
  inProgress('in_progress');

  const FinalMileBatchStatus(this.apiValue);

  final String apiValue;

  static FinalMileBatchStatus fromApi(Object? value) {
    return switch (value) {
      'offered' => FinalMileBatchStatus.offered,
      'accepted' => FinalMileBatchStatus.accepted,
      'in_progress' => FinalMileBatchStatus.inProgress,
      _ => throw const ApiContractException('batch.status'),
    };
  }
}

class FinalMileBatchDestination {
  const FinalMileBatchDestination({
    this.barangay,
    this.cityMunicipality,
    this.province,
    this.region,
  });

  final String? barangay;
  final String? cityMunicipality;
  final String? province;
  final String? region;

  String get summary {
    final parts = <String>[?barangay, ?cityMunicipality, ?province, ?region];
    return parts.isEmpty ? 'Destination area unavailable' : parts.join(', ');
  }

  factory FinalMileBatchDestination.fromJson(Object? value) {
    if (value is! Map) {
      return const FinalMileBatchDestination();
    }
    final json = Map<String, dynamic>.from(value);
    return FinalMileBatchDestination(
      barangay: _nullableString(json['barangay']),
      cityMunicipality: _nullableString(json['city_municipality']),
      province: _nullableString(json['province']),
      region: _nullableString(json['region']),
    );
  }
}

class FinalMileBatchParcel {
  const FinalMileBatchParcel({
    this.id,
    this.reference,
    this.itemCount,
    this.price,
    this.currency,
  });

  final String? id;
  final String? reference;
  final int? itemCount;
  final String? price;
  final String? currency;

  String get itemSummary {
    final count = itemCount;
    if (count == null) return 'Item count unavailable';
    return '$count ${count == 1 ? 'item' : 'items'}';
  }

  String get priceSummary {
    final amount = price;
    final code = currency;
    if (amount == null || code == null) return 'Parcel price unavailable';
    return '$code $amount';
  }

  factory FinalMileBatchParcel.fromJson(Object? value) {
    if (value is! Map) {
      throw const ApiContractException('batch.task.parcel');
    }
    final json = Map<String, dynamic>.from(value);
    return FinalMileBatchParcel(
      id: _nullableString(json['id']),
      reference: _nullableString(json['reference']),
      itemCount: _nullableInt(json['item_count']),
      price: _nullableDecimal(json['price']),
      currency: _nullableString(json['currency']),
    );
  }
}

class FinalMileBatchTask {
  const FinalMileBatchTask({
    required this.id,
    required this.status,
    required this.parcel,
    required this.destination,
    this.orderReference,
  });

  final String id;
  final String status;
  final String? orderReference;
  final FinalMileBatchParcel parcel;
  final FinalMileBatchDestination destination;

  factory FinalMileBatchTask.fromJson(Object? value) {
    if (value is! Map) {
      throw const ApiContractException('batch.task');
    }
    final json = Map<String, dynamic>.from(value);
    final order = json['order'];
    final orderJson = order is Map
        ? Map<String, dynamic>.from(order)
        : const <String, dynamic>{};
    return FinalMileBatchTask(
      id: _requiredString(json['id'] ?? json['task_id'], 'batch.task.id'),
      status: _requiredTaskStatus(json['status']),
      orderReference: _nullableString(orderJson['reference']),
      parcel: FinalMileBatchParcel.fromJson(json['parcel']),
      destination: FinalMileBatchDestination.fromJson(json['destination_area']),
    );
  }
}

String _requiredTaskStatus(Object? value) {
  final status = _requiredString(value, 'batch.task.status');
  const allowed = <String>{
    'delivery_assigned',
    'delivery_accepted',
    'picked_up_from_hub',
    'in_transit',
    'out_for_delivery',
    'delivered',
  };
  if (!allowed.contains(status)) {
    throw const ApiContractException('batch.task.status');
  }
  return status;
}

class FinalMileBatch {
  const FinalMileBatch({
    required this.id,
    required this.reference,
    required this.scheduledFor,
    required this.parcelCount,
    required this.status,
    required this.tasks,
  });

  final String id;
  final String reference;
  final DateTime scheduledFor;
  final int parcelCount;
  final FinalMileBatchStatus status;
  final List<FinalMileBatchTask> tasks;

  bool get canAccept => status == FinalMileBatchStatus.offered;

  bool get isAccepted =>
      status == FinalMileBatchStatus.accepted ||
      status == FinalMileBatchStatus.inProgress;

  factory FinalMileBatch.fromJson(Object? value) {
    if (value is! Map) {
      throw const ApiContractException('batch.item');
    }
    final json = Map<String, dynamic>.from(value);
    final parcelCount = _requiredInt(
      json['parcel_count'],
      'batch.parcel_count',
    );
    final rawTasks = json['tasks'];
    if (parcelCount < 1 || parcelCount > 15 || rawTasks is! List) {
      throw const ApiContractException('batch.tasks');
    }
    final tasks = rawTasks
        .map(FinalMileBatchTask.fromJson)
        .toList(growable: false);
    if (tasks.length != parcelCount) {
      throw const ApiContractException('batch.parcel_count');
    }
    return FinalMileBatch(
      id: _requiredString(json['id'], 'batch.id'),
      reference: _requiredString(json['reference'], 'batch.reference'),
      scheduledFor: _requiredUtc(json['scheduled_for'], 'batch.scheduled_for'),
      parcelCount: parcelCount,
      status: FinalMileBatchStatus.fromApi(json['status']),
      tasks: List<FinalMileBatchTask>.unmodifiable(tasks),
    );
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value.trim();
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const ApiContractException('batch.string');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requiredInt(Object? value, String field) {
  final result = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (result == null) throw ApiContractException(field);
  return result;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  final result = value is int ? value : int.tryParse(value.toString());
  if (result == null || result < 0) {
    throw const ApiContractException('batch.integer');
  }
  return result;
}

String? _nullableDecimal(Object? value) {
  if (value == null) return null;
  if (value is! num && value is! String) {
    throw const ApiContractException('batch.decimal');
  }
  final text = value.toString().trim();
  if (text.isEmpty || num.tryParse(text) == null) {
    throw const ApiContractException('batch.decimal');
  }
  return text;
}

DateTime _requiredUtc(Object? value, String field) {
  if (value is! String) throw ApiContractException(field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw ApiContractException(field);
  return parsed.toUtc();
}
