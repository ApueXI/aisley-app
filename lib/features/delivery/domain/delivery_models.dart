import '../../../core/networking/api_contract_exception.dart';
import '../../pickup/domain/pickup_models.dart';

class DeliveryContext {
  const DeliveryContext({
    required this.taskId,
    required this.status,
    this.revision,
    this.hub,
    this.destination,
    this.recipientName,
    this.recipientPhone,
    this.deliveryInstructions,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.routeStatus,
    this.calculatedAt,
  });

  final String taskId;
  final String status;
  final int? revision;
  final PickupLocation? hub;
  final PickupLocation? destination;
  final String? recipientName;
  final String? recipientPhone;
  final String? deliveryInstructions;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final String? routeStatus;
  final DateTime? calculatedAt;

  factory DeliveryContext.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'delivery.context.data');
    final rawTask = data['task'];
    final task = rawTask is Map
        ? Map<String, dynamic>.from(rawTask)
        : const <String, dynamic>{};
    final source = <String, dynamic>{...task, ...data};

    final taskId = _requiredString(
      source['task_id'] ?? source['id'],
      'delivery.context.task_id',
    );
    final rawStatus = source['status'] ?? source['state'];
    final status = _requiredString(rawStatus, 'delivery.context.status');
    parsePickupTaskStatus(status);

    return DeliveryContext(
      taskId: taskId,
      status: status,
      revision: _nullableInt(source['revision']),
      hub: _locationFrom(
        source['hub'] ?? source['pickup_hub'] ?? source['pickup'],
      ),
      destination: _locationFrom(
        source['destination'] ?? source['delivery_address'],
      ),
      recipientName: _contactString(
        source,
        keys: const <String>['recipient_name', 'buyer_name'],
        nestedKeys: const <String>['name', 'full_name'],
      ),
      recipientPhone: _contactString(
        source,
        keys: const <String>['recipient_phone', 'buyer_phone'],
        nestedKeys: const <String>['phone', 'contact_number'],
      ),
      deliveryInstructions: _firstString(source, const <String>[
        'delivery_instructions',
        'instructions',
      ]),
      distanceKm: _nullableDouble(source['distance_km']),
      estimatedDurationMinutes: _nullableInt(
        source['estimated_duration_minutes'],
      ),
      routeStatus: _firstString(source, const <String>['route_status']),
      calculatedAt: _nullableDateTime(source['calculated_at']),
    );
  }

  DeliveryContext copyWith({String? status, int? revision}) {
    return DeliveryContext(
      taskId: taskId,
      status: status ?? this.status,
      revision: revision ?? this.revision,
      hub: hub,
      destination: destination,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      deliveryInstructions: deliveryInstructions,
      distanceKm: distanceKm,
      estimatedDurationMinutes: estimatedDurationMinutes,
      routeStatus: routeStatus,
      calculatedAt: calculatedAt,
    );
  }
}

class DeliveryStatusUpdate {
  const DeliveryStatusUpdate({
    required this.taskId,
    required this.status,
    this.revision,
  });

  final String taskId;
  final String status;
  final int? revision;

  factory DeliveryStatusUpdate.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'delivery.status.data');
    final taskId = _requiredString(
      data['task_id'] ?? data['id'],
      'delivery.status.task_id',
    );
    final status = _requiredString(
      data['status'] ?? data['state'],
      'delivery.status.status',
    );
    parsePickupTaskStatus(status);
    return DeliveryStatusUpdate(
      taskId: taskId,
      status: status,
      revision: _nullableInt(data['revision']),
    );
  }
}

class ProofSubmission {
  const ProofSubmission({
    required this.taskId,
    required this.proofId,
    required this.evidenceStatus,
    required this.custodyState,
    required this.completionEligible,
    this.submittedAt,
  });

  final String taskId;
  final String proofId;
  final String evidenceStatus;
  final String custodyState;
  final bool completionEligible;
  final DateTime? submittedAt;

  factory ProofSubmission.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'delivery.proof.data');
    final completionEligible = data['completion_eligible'];
    if (completionEligible is! bool) {
      throw const ApiContractException('delivery.proof.completion_eligible');
    }
    return ProofSubmission(
      taskId: _requiredString(data['task_id'], 'delivery.proof.task_id'),
      proofId: _requiredString(data['proof_id'], 'delivery.proof.proof_id'),
      evidenceStatus: _requiredString(
        data['evidence_status'],
        'delivery.proof.evidence_status',
      ),
      custodyState: _requiredString(
        data['custody_state'],
        'delivery.proof.custody_state',
      ),
      completionEligible: completionEligible,
      submittedAt: _nullableDateTime(data['submitted_at']),
    );
  }
}

class CompletionProjection {
  const CompletionProjection({
    required this.taskId,
    required this.taskStatus,
    required this.completionStatus,
    this.intentId,
    this.orderStatus,
    this.evidenceStatus,
    this.evidenceId,
    this.deliveredAt,
    this.revision,
  });

  final String taskId;
  final String taskStatus;
  final String? completionStatus;
  final String? intentId;
  final String? orderStatus;
  final String? evidenceStatus;
  final String? evidenceId;
  final DateTime? deliveredAt;
  final int? revision;

  bool get isDelivered => taskStatus == 'delivered';

  bool get isAwaitingValidation =>
      intentId != null && completionStatus == 'awaiting_validation';

  bool get isProofAwaitingValidation => evidenceStatus == 'awaiting_validation';

  factory CompletionProjection.fromResponse(Map<String, dynamic> json) {
    final data = _completionData(json);
    final taskStatus = _requiredString(
      data['task_status'] ?? data['status'],
      'delivery.completion.task_status',
    );
    parsePickupTaskStatus(taskStatus);
    if (!data.containsKey('completion_status')) {
      throw const ApiContractException('delivery.completion.completion_status');
    }
    return CompletionProjection(
      taskId: _requiredString(data['task_id'], 'delivery.completion.task_id'),
      taskStatus: taskStatus,
      completionStatus: _nullableString(
        data['completion_status'],
        'delivery.completion.completion_status',
      ),
      intentId: _nullableString(data['intent_id']),
      orderStatus: _nullableString(data['order_status']),
      evidenceStatus: _nullableString(data['evidence_status']),
      evidenceId: _nullableString(data['evidence_id']),
      deliveredAt: _nullableDateTime(data['delivered_at']),
      revision: _nullableInt(data['revision']),
    );
  }
}

Map<String, dynamic> _completionData(Map<String, dynamic> json) {
  final rawData = json['data'];
  if (rawData is Map) {
    return Map<String, dynamic>.from(rawData);
  }

  // The documented Laravel response uses the data envelope. Keep this narrow
  // direct-DTO compatibility for deployments that serialize this
  // endpoint-specific projection without that envelope; never treat an
  // arbitrary successful JSON object as a completion projection.
  if (json['task_id'] is String &&
      (json['task_status'] is String || json['status'] is String) &&
      json.containsKey('completion_status') &&
      (json['completion_status'] == null ||
          json['completion_status'] is String)) {
    return json;
  }

  throw const ApiContractException('delivery.completion.data');
}

String? _contactString(
  Map<String, dynamic> source, {
  required List<String> keys,
  required List<String> nestedKeys,
}) {
  final direct = _firstString(source, keys);
  if (direct != null) {
    return direct;
  }
  for (final nestedName in const <String>['recipient', 'buyer', 'contact']) {
    final nested = source[nestedName];
    if (nested is Map) {
      final value = _firstString(Map<String, dynamic>.from(nested), nestedKeys);
      if (value != null) {
        return value;
      }
    }
  }
  return null;
}

PickupLocation? _locationFrom(Object? value) {
  return value is Map ? PickupLocation.fromJson(value) : null;
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
  return value.trim();
}

String? _nullableString(Object? value, [String field = 'delivery.value']) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? _firstString(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = _nullableString(source[key]);
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
    throw const ApiContractException('delivery.integer');
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
    throw const ApiContractException('delivery.number');
  }
  return parsed;
}

DateTime? _nullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const ApiContractException('delivery.timestamp');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const ApiContractException('delivery.timestamp');
  }
  return parsed.toUtc();
}
