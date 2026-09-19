part of '../pickup_models.dart';

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
