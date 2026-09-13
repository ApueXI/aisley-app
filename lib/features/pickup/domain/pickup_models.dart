import '../../../core/networking/api_contract_exception.dart';

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
      status == PickupTaskStatus.pickedUpFromHub ||
      status == PickupTaskStatus.inTransit ||
      status == PickupTaskStatus.outForDelivery ||
      status == PickupTaskStatus.delivered;

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

class WaybillResolution {
  const WaybillResolution({
    this.taskId,
    this.orderId,
    this.orderReference,
    this.waybillReference,
    this.taskStatus,
  });

  final String? taskId;
  final String? orderId;
  final String? orderReference;
  final String? waybillReference;
  final String? taskStatus;

  factory WaybillResolution.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.resolve.data');
    final task = data['task'] is Map
        ? Map<String, dynamic>.from(data['task'] as Map)
        : const <String, dynamic>{};
    final rawOrder = data['order'] ?? task['order'];
    final order = rawOrder is Map
        ? PickupOrderReference.fromJson(rawOrder)
        : PickupOrderReference(
            id: _nullableString(data['order_id']),
            reference: _nullableString(data['order_reference']),
          );
    final rawWaybill = data['waybill'] ?? task['waybill'];
    final waybill = rawWaybill is Map
        ? PickupWaybillReference.fromJson(rawWaybill)
        : PickupWaybillReference(
            reference: _nullableString(data['waybill_reference']),
          );
    final taskId = _nullableString(data['task_id'] ?? task['id']);
    final taskStatus = _nullableString(data['task_status'] ?? task['status']);

    if (taskId == null && order.id == null && order.reference == null) {
      throw const ApiContractException('pickup.resolve.match');
    }

    return WaybillResolution(
      taskId: taskId,
      orderId: order.id,
      orderReference: order.reference,
      waybillReference: waybill.reference,
      taskStatus: taskStatus,
    );
  }
}

class FirstMilePickupResult {
  const FirstMilePickupResult({
    required this.taskId,
    required this.taskStatus,
    required this.orderStatus,
    this.order,
    this.waybill,
    this.pickedUpAt,
    this.nextStep,
    this.idempotent = false,
  });

  final String taskId;
  final String taskStatus;
  final String orderStatus;
  final PickupOrderReference? order;
  final PickupWaybillReference? waybill;
  final DateTime? pickedUpAt;
  final String? nextStep;
  final bool idempotent;

  factory FirstMilePickupResult.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.confirm.data');
    final taskId = _requiredString(
      data['task_id'] ?? data['id'],
      'pickup.confirm.task_id',
    );
    final taskStatus = _requiredString(
      data['task_status'] ?? data['status'],
      'pickup.confirm.task_status',
    );
    final orderStatus = _requiredString(
      data['order_status'],
      'pickup.confirm.order_status',
    );
    if (taskStatus != 'picked_up_from_seller' || orderStatus != 'picked_up') {
      throw const ApiContractException('pickup.confirm.committed_state');
    }

    return FirstMilePickupResult(
      taskId: taskId,
      taskStatus: taskStatus,
      orderStatus: orderStatus,
      order: data.containsKey('order')
          ? PickupOrderReference.fromJson(data['order'])
          : null,
      waybill: data.containsKey('waybill')
          ? PickupWaybillReference.fromJson(data['waybill'])
          : null,
      pickedUpAt: _nullableUtc(data['picked_up_at']),
      nextStep: _nullableString(data['next_step']),
      idempotent: data['idempotent'] == true,
    );
  }
}

class FinalMilePickupSubmission {
  const FinalMilePickupSubmission({
    required this.taskId,
    required this.evidenceId,
    required this.evidenceStatus,
    required this.custodyState,
    this.submittedAt,
  });

  final String taskId;
  final String evidenceId;
  final String evidenceStatus;
  final String custodyState;
  final DateTime? submittedAt;

  factory FinalMilePickupSubmission.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.final_mile.data');
    final evidenceStatus = _requiredString(
      data['evidence_status'],
      'pickup.final_mile.evidence_status',
    );
    if (evidenceStatus != 'awaiting_validation') {
      throw const ApiContractException('pickup.final_mile.pending_state');
    }

    return FinalMilePickupSubmission(
      taskId: _requiredString(data['task_id'], 'pickup.final_mile.task_id'),
      evidenceId: _requiredString(
        data['evidence_id'],
        'pickup.final_mile.evidence_id',
      ),
      evidenceStatus: evidenceStatus,
      custodyState: _requiredString(
        data['custody_state'],
        'pickup.final_mile.custody_state',
      ),
      submittedAt: _nullableUtc(data['submitted_at']),
    );
  }
}

class FinalMileRejectionResult {
  const FinalMileRejectionResult({
    required this.taskId,
    required this.status,
    this.rejectionReason,
    this.respondedAt,
  });

  final String taskId;
  final String status;
  final String? rejectionReason;
  final DateTime? respondedAt;

  factory FinalMileRejectionResult.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.final_mile.reject.data');
    final status = _requiredString(
      data['status'],
      'pickup.final_mile.reject.status',
    );
    if (status != 'rejected') {
      throw const ApiContractException('pickup.final_mile.reject.state');
    }
    final rawOffer = data['offer'];
    final offer = rawOffer is Map
        ? Map<String, dynamic>.from(rawOffer)
        : const <String, dynamic>{};
    return FinalMileRejectionResult(
      taskId: _requiredString(
        data['task_id'],
        'pickup.final_mile.reject.task_id',
      ),
      status: status,
      rejectionReason: _nullableString(
        data['rejection_reason'] ?? offer['rejection_reason'],
      ),
      respondedAt: _nullableUtc(data['responded_at'] ?? offer['responded_at']),
    );
  }
}

enum RouteManifestStatus { pending, ready, unavailable, unknown }

RouteManifestStatus parseRouteManifestStatus(Object? value) {
  return switch (value) {
    'pending' => RouteManifestStatus.pending,
    'ready' => RouteManifestStatus.ready,
    'unavailable' => RouteManifestStatus.unavailable,
    _ => RouteManifestStatus.unknown,
  };
}

class PickupRouteManifest {
  const PickupRouteManifest({
    required this.status,
    this.scheduleId,
    this.revision,
    this.coordinateSource,
    this.summary,
    this.stops = const <PickupRouteStop>[],
    this.geoJson,
    this.calculatedAt,
    this.reason,
    this.map,
  });

  final RouteManifestStatus status;
  final String? scheduleId;
  final int? revision;
  final String? coordinateSource;
  final Map<String, dynamic>? summary;
  final List<PickupRouteStop> stops;
  final Map<String, dynamic>? geoJson;
  final DateTime? calculatedAt;
  final String? reason;
  final Map<String, dynamic>? map;

  factory PickupRouteManifest.fromResponse(Map<String, dynamic> json) {
    final data = _requiredMap(json['data'], 'pickup.manifest.data');
    final rawStops = data['stops'];
    final stops = <PickupRouteStop>[];
    if (rawStops is List) {
      for (var index = 0; index < rawStops.length; index++) {
        final value = rawStops[index];
        if (value is! Map) {
          throw const ApiContractException('pickup.manifest.stop');
        }
        stops.add(
          PickupRouteStop.fromJson(
            Map<String, dynamic>.from(value),
            fallbackSequence: index,
          ),
        );
      }
    }

    return PickupRouteManifest(
      status: parseRouteManifestStatus(data['status']),
      scheduleId: _nullableString(
        data['schedule_id'] ??
            (data['schedule'] is Map ? (data['schedule'] as Map)['id'] : null),
      ),
      revision: _nullableInt(data['revision']),
      coordinateSource: _nullableString(data['coordinate_source']),
      summary: _nullableMap(data['summary']),
      stops: stops,
      geoJson: _nullableMap(data['geojson']),
      calculatedAt: _nullableUtc(data['calculated_at']),
      reason: _nullableString(data['reason']),
      map: _nullableMap(data['map']),
    );
  }
}

class PickupRouteStop {
  const PickupRouteStop({
    required this.sequence,
    required this.kind,
    this.taskIds = const <String>[],
    this.orderReferences = const <String>[],
    this.waybillReferences = const <String>[],
    this.addressSummary,
    this.latitude,
    this.longitude,
    this.coordinateSource,
    this.legDistanceMeters,
    this.legTimeSeconds,
    this.reachable,
  });

  final int sequence;
  final String kind;
  final List<String> taskIds;
  final List<String> orderReferences;
  final List<String> waybillReferences;
  final String? addressSummary;
  final double? latitude;
  final double? longitude;
  final String? coordinateSource;
  final double? legDistanceMeters;
  final int? legTimeSeconds;
  final bool? reachable;

  bool get isHub => kind == 'hub';

  factory PickupRouteStop.fromJson(
    Map<String, dynamic> json, {
    required int fallbackSequence,
  }) {
    return PickupRouteStop(
      sequence: _nullableInt(json['sequence']) ?? fallbackSequence,
      kind: _nullableString(json['kind']) ?? 'unknown',
      taskIds: _stringList(json['task_ids'], fallback: json['task_id']),
      orderReferences: _stringList(
        json['order_references'],
        fallback: json['order_reference'],
      ),
      waybillReferences: _stringList(
        json['waybill_references'],
        fallback: json['waybill_reference'],
      ),
      addressSummary: _addressSummary(json),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      coordinateSource: _nullableString(json['coordinate_source']),
      legDistanceMeters: _nullableDouble(json['leg_distance_meters']),
      legTimeSeconds: _nullableInt(json['leg_time_seconds']),
      reachable: json['reachable'] is bool ? json['reachable'] as bool : null,
    );
  }
}

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
