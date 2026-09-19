part of '../pickup_models.dart';

enum PickupTaskLeg {
  firstMile('first_mile'),
  finalMile('final_mile'),
  unknown('unknown');

  const PickupTaskLeg(this.apiValue);

  final String apiValue;

  static PickupTaskLeg fromApi(
    Object? value, {
    PickupTaskLeg fallback = PickupTaskLeg.unknown,
  }) {
    return switch (value) {
      'first_mile' => PickupTaskLeg.firstMile,
      'final_mile' => PickupTaskLeg.finalMile,
      _ => fallback,
    };
  }
}

enum PickupTaskStatus {
  assigned,
  accepted,
  pickedUpFromSeller,
  deliveryAssigned,
  deliveryAccepted,
  pickedUpFromHub,
  inTransit,
  outForDelivery,
  delivered,
  rejected,
  cancelled,
  unknown,
}

PickupTaskStatus parsePickupTaskStatus(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const ApiContractException('pickup.task.status');
  }

  return switch (value) {
    'assigned' => PickupTaskStatus.assigned,
    'accepted' => PickupTaskStatus.accepted,
    'picked_up_from_seller' => PickupTaskStatus.pickedUpFromSeller,
    'delivery_assigned' => PickupTaskStatus.deliveryAssigned,
    'delivery_accepted' => PickupTaskStatus.deliveryAccepted,
    'picked_up_from_hub' => PickupTaskStatus.pickedUpFromHub,
    'in_transit' => PickupTaskStatus.inTransit,
    'out_for_delivery' => PickupTaskStatus.outForDelivery,
    'delivered' => PickupTaskStatus.delivered,
    'rejected' => PickupTaskStatus.rejected,
    'cancelled' => PickupTaskStatus.cancelled,
    _ => PickupTaskStatus.unknown,
  };
}

class PickupOrderReference {
  const PickupOrderReference({this.id, this.reference});

  final String? id;
  final String? reference;

  String get displayReference =>
      reference ?? id ?? 'Order reference unavailable';

  factory PickupOrderReference.fromJson(Object? value) {
    if (value is! Map) {
      return const PickupOrderReference();
    }
    final json = Map<String, dynamic>.from(value);
    return PickupOrderReference(
      id: _nullableString(json['id'] ?? json['order_id']),
      reference: _nullableString(json['reference'] ?? json['order_reference']),
    );
  }
}

class PickupWaybillReference {
  const PickupWaybillReference({this.id, this.reference});

  final String? id;
  final String? reference;

  String get displayReference =>
      reference ?? id ?? 'Waybill reference unavailable';

  factory PickupWaybillReference.fromJson(Object? value) {
    if (value is! Map) {
      return const PickupWaybillReference();
    }
    final json = Map<String, dynamic>.from(value);
    return PickupWaybillReference(
      id: _nullableString(json['id'] ?? json['waybill_id']),
      reference: _nullableString(
        json['reference'] ?? json['waybill_reference'],
      ),
    );
  }
}

class PickupLocation {
  const PickupLocation({
    this.name,
    this.addressLine1,
    this.addressLine2,
    this.barangay,
    this.cityMunicipality,
    this.province,
    this.region,
    this.postalCode,
  });

  final String? name;
  final String? addressLine1;
  final String? addressLine2;
  final String? barangay;
  final String? cityMunicipality;
  final String? province;
  final String? region;
  final String? postalCode;

  bool get hasFullAddress =>
      addressLine1 != null &&
      barangay != null &&
      cityMunicipality != null &&
      province != null &&
      region != null &&
      postalCode != null;

  String get areaSummary {
    final parts = <String>[?barangay, ?cityMunicipality, ?province];
    return parts.isEmpty ? 'Location unavailable' : parts.join(', ');
  }

  String get fullAddress {
    final parts = <String>[
      ?name,
      ?addressLine1,
      ?addressLine2,
      ?barangay,
      ?cityMunicipality,
      ?province,
      ?region,
      ?postalCode,
    ];
    return parts.isEmpty ? 'Address unavailable' : parts.join(', ');
  }

  factory PickupLocation.fromJson(Object? value) {
    if (value is! Map) {
      return const PickupLocation();
    }

    final source = Map<String, dynamic>.from(value);
    final nestedAddress = source['address'];
    final address = nestedAddress is Map
        ? Map<String, dynamic>.from(nestedAddress)
        : source;

    return PickupLocation(
      name: _firstString(source, const <String>[
        'shop_name',
        'hub_name',
        'business_name',
        'name',
      ]),
      addressLine1: _firstString(address, const <String>[
        'address_line_1',
        'line_1',
      ]),
      addressLine2: _firstString(address, const <String>[
        'address_line_2',
        'line_2',
      ]),
      barangay: _firstString(address, const <String>['barangay']),
      cityMunicipality: _firstString(address, const <String>[
        'city_municipality',
      ]),
      province: _firstString(address, const <String>['province']),
      region: _firstString(address, const <String>['region']),
      postalCode: _firstString(address, const <String>['postal_code']),
    );
  }
}

class PickupSchedule {
  const PickupSchedule({
    this.id,
    this.reference,
    this.startsAt,
    this.endsAt,
    this.timezone,
  });

  final String? id;
  final String? reference;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? timezone;

  String? get displayId => reference ?? id;

  factory PickupSchedule.fromJson(Object? value) {
    if (value is! Map) {
      return const PickupSchedule();
    }

    final json = Map<String, dynamic>.from(value);
    return PickupSchedule(
      id: _nullableString(json['id'] ?? json['pickup_schedule_id']),
      reference: _nullableString(
        json['reference'] ?? json['schedule_reference'],
      ),
      startsAt: _nullableUtc(json['starts_at']),
      endsAt: _nullableUtc(json['ends_at']),
      timezone: _nullableString(json['timezone']),
    );
  }
}

class PickupTask {
  const PickupTask({
    required this.id,
    required this.leg,
    required this.rawStatus,
    this.revision,
    this.pickedUpAt,
    this.order,
    this.waybill,
    this.pickup,
    this.destinationArea,
    this.schedule,
    this.pickupScheduleId,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.evidenceStatus,
    this.rejectionReason,
    this.offerRespondedAt,
  });

  final String id;
  final PickupTaskLeg leg;
  final String rawStatus;
  final int? revision;
  final DateTime? pickedUpAt;
  final PickupOrderReference? order;
  final PickupWaybillReference? waybill;
  final PickupLocation? pickup;
  final PickupLocation? destinationArea;
  final PickupSchedule? schedule;
  final String? pickupScheduleId;
  final double? distanceKm;
  final int? estimatedDurationMinutes;
  final String? evidenceStatus;
  final String? rejectionReason;
  final DateTime? offerRespondedAt;

  PickupTaskStatus get status => parsePickupTaskStatus(rawStatus);

  bool get isFirstMile => leg == PickupTaskLeg.firstMile;

  bool get isFinalMile => leg == PickupTaskLeg.finalMile;

  bool get isAccepted =>
      status == PickupTaskStatus.accepted ||
      status == PickupTaskStatus.deliveryAccepted;

  bool get isAssigned =>
      status == PickupTaskStatus.assigned ||
      status == PickupTaskStatus.deliveryAssigned;

  bool get hasBeenPickedUp =>
      status == PickupTaskStatus.pickedUpFromSeller ||
      status == PickupTaskStatus.pickedUpFromHub;

  PickupTask copyWith({
    String? rawStatus,
    DateTime? pickedUpAt,
    int? revision,
    String? rejectionReason,
    DateTime? offerRespondedAt,
  }) {
    return PickupTask(
      id: id,
      leg: leg,
      rawStatus: rawStatus ?? this.rawStatus,
      revision: revision ?? this.revision,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      order: order,
      waybill: waybill,
      pickup: pickup,
      destinationArea: destinationArea,
      schedule: schedule,
      pickupScheduleId: pickupScheduleId,
      distanceKm: distanceKm,
      estimatedDurationMinutes: estimatedDurationMinutes,
      evidenceStatus: evidenceStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      offerRespondedAt: offerRespondedAt ?? this.offerRespondedAt,
    );
  }

  factory PickupTask.fromJson(
    Map<String, dynamic> json, {
    required PickupTaskLeg defaultLeg,
  }) {
    final id = _requiredString(json['id'] ?? json['task_id'], 'pickup.task.id');
    final rawStatus = _requiredString(
      json['status'] ?? json['state'],
      'pickup.task.status',
    );
    final leg = PickupTaskLeg.fromApi(json['leg'], fallback: defaultLeg);
    parsePickupTaskStatus(rawStatus);

    final rawSchedule = json['schedule'];
    final schedule = PickupSchedule.fromJson(rawSchedule);
    final pickupScheduleId = _nullableString(
      json['pickup_schedule_id'] ?? schedule.id,
    );
    final rawPickup = json['pickup'] ?? json['hub'];
    final rawDestination = json['destination_area'] ?? json['destination'];
    final rawOffer = json['offer'];
    final offer = rawOffer is Map
        ? Map<String, dynamic>.from(rawOffer)
        : const <String, dynamic>{};

    return PickupTask(
      id: id,
      leg: leg,
      rawStatus: rawStatus,
      revision: _nullableInt(json['revision']),
      pickedUpAt: _nullableUtc(json['picked_up_at']),
      order: json.containsKey('order')
          ? PickupOrderReference.fromJson(json['order'])
          : _orderFromFlatFields(json),
      waybill: json.containsKey('waybill')
          ? PickupWaybillReference.fromJson(json['waybill'])
          : _waybillFromFlatFields(json),
      pickup: rawPickup is Map
          ? PickupLocation.fromJson(rawPickup)
          : const PickupLocation(),
      destinationArea: rawDestination is Map
          ? PickupLocation.fromJson(rawDestination)
          : const PickupLocation(),
      schedule: schedule,
      pickupScheduleId: pickupScheduleId,
      distanceKm: _nullableDouble(json['distance_km']),
      estimatedDurationMinutes: _nullableInt(
        json['estimated_duration_minutes'],
      ),
      evidenceStatus: _nullableString(json['evidence_status']),
      rejectionReason: _nullableString(
        json['rejection_reason'] ?? offer['rejection_reason'],
      ),
      offerRespondedAt: _nullableUtc(
        json['responded_at'] ?? offer['responded_at'],
      ),
    );
  }
}

class FirstMileTaskPage {
  const FirstMileTaskPage({
    required this.tasks,
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
  });

  final List<PickupTask> tasks;
  final int? currentPage;
  final int? lastPage;
  final int? perPage;
  final int? total;

  bool get hasMore =>
      currentPage != null && lastPage != null && currentPage! < lastPage!;
}
