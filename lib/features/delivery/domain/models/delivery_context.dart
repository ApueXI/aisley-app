part of '../delivery_models.dart';

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
    this.paymentMethod,
    this.paymentStatus,
    this.payableTotal,
    this.currency,
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
  final String? paymentMethod;
  final String? paymentStatus;
  final String? payableTotal;
  final String? currency;

  DeliveryCodCollection? get codCollection {
    final amount = payableTotal;
    final unit = currency;
    if (paymentMethod != 'cod' ||
        paymentStatus != 'pending' ||
        amount == null ||
        unit == null ||
        !RegExp(r'^\d{1,10}(?:\.\d{1,2})?$').hasMatch(amount) ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(unit)) {
      return null;
    }
    return DeliveryCodCollection(amount: amount, currency: unit);
  }

  factory DeliveryContext.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'delivery.context.data');
    final rawTask = data['task'];
    final task = rawTask is Map
        ? Map<String, dynamic>.from(rawTask)
        : const <String, dynamic>{};
    final source = <String, dynamic>{...task, ...data};
    final rawOrder = source['order'];
    final order = rawOrder is Map
        ? Map<String, dynamic>.from(rawOrder)
        : const <String, dynamic>{};

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
      paymentMethod: _nullableString(
        order['payment_method'],
        'delivery.context.order.payment_method',
      ),
      paymentStatus: _nullableString(
        order['payment_status'],
        'delivery.context.order.payment_status',
      ),
      payableTotal: _nullableString(
        order['payable_total'],
        'delivery.context.order.payable_total',
      ),
      currency: _nullableString(
        order['currency'],
        'delivery.context.order.currency',
      ),
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
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      payableTotal: payableTotal,
      currency: currency,
    );
  }
}

class DeliveryCodCollection {
  const DeliveryCodCollection({required this.amount, required this.currency});

  final String amount;
  final String currency;

  String get displayAmount => '$currency $amount';

  bool matches(DeliveryCodCollection other) =>
      amount == other.amount && currency == other.currency;
}
