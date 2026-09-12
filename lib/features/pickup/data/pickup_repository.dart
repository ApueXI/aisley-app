import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/pickup_models.dart';

abstract interface class PickupRepository {
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  });

  Future<PickupTask> acceptFirstMileTask(String taskId);

  Future<WaybillResolution> resolveWaybill(String payload);

  Future<FirstMilePickupResult> confirmFirstMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required String idempotencyKey,
  });

  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId);

  Future<List<PickupTask>> fetchFinalMileTasks();

  Future<PickupTask> fetchFinalMileTask(String taskId);

  Future<PickupTask> acceptFinalMileTask(String taskId);

  Future<FinalMilePickupSubmission> submitFinalMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

class ApiPickupRepository implements PickupRepository {
  ApiPickupRepository({required this._client});

  final ApiClient _client;

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    if (perPage < 1 || perPage > 50) {
      throw ArgumentError.value(perPage, 'perPage', 'must be between 1 and 50');
    }

    final normalizedSchedule = pickupScheduleId?.trim();
    final response = await _client.get(
      '/courier/first-mile-tasks',
      authenticated: true,
      queryParameters: <String, String>{
        'per_page': '$perPage',
        if (normalizedSchedule != null && normalizedSchedule.isNotEmpty)
          'pickup_schedule_id': normalizedSchedule,
      },
    );
    final payload = _decodeObject(response.body, 'pickup.first_mile.list');
    final rawData = payload['data'];
    if (rawData is! List) {
      throw const ApiContractException('pickup.first_mile.data');
    }

    final tasks = <PickupTask>[];
    for (final item in rawData) {
      if (item is! Map) {
        throw const ApiContractException('pickup.first_mile.item');
      }
      tasks.add(
        PickupTask.fromJson(
          Map<String, dynamic>.from(item),
          defaultLeg: PickupTaskLeg.firstMile,
        ),
      );
    }

    final meta = payload['meta'] is Map
        ? Map<String, dynamic>.from(payload['meta'] as Map)
        : const <String, dynamic>{};
    return FirstMileTaskPage(
      tasks: tasks,
      currentPage: _nullableInt(meta['current_page']),
      lastPage: _nullableInt(meta['last_page']),
      perPage: _nullableInt(meta['per_page']),
      total: _nullableInt(meta['total']),
    );
  }

  @override
  Future<PickupTask> acceptFirstMileTask(String taskId) async {
    final response = await _client.postJson(
      '/courier/first-mile-tasks/${_pathSegment(taskId)}/accept',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.first_mile.accept');
    return _taskFromData(payload, PickupTaskLeg.firstMile);
  }

  @override
  Future<WaybillResolution> resolveWaybill(String payload) async {
    final normalizedPayload = payload.trim();
    if (normalizedPayload.isEmpty || normalizedPayload.length > 128) {
      throw const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'The waybill QR payload is invalid.',
      );
    }

    final response = await _client.postJson(
      '/courier/waybills/resolve',
      authenticated: true,
      body: <String, Object?>{'payload': normalizedPayload},
    );
    final decoded = _decodeObject(response.body, 'pickup.resolve');
    return WaybillResolution.fromResponse(decoded);
  }

  @override
  Future<FirstMilePickupResult> confirmFirstMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required String idempotencyKey,
  }) async {
    final response = await _client.postJson(
      '/courier/first-mile-tasks/${_pathSegment(taskId)}/pickup',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'identifier_type': identifierType,
        'identifier': identifier.trim(),
      },
    );
    final payload = _decodeObject(response.body, 'pickup.confirm');
    return FirstMilePickupResult.fromResponse(payload);
  }

  @override
  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId) async {
    final response = await _client.get(
      '/courier/pickup-schedules/${_pathSegment(scheduleId)}/route-manifest',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.manifest');
    return PickupRouteManifest.fromResponse(payload);
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    final response = await _client.get(
      '/courier/final-mile-tasks',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile.list');
    final rawData = payload['data'];
    if (rawData is! List) {
      throw const ApiContractException('pickup.final_mile.data');
    }

    final tasks = <PickupTask>[];
    for (final item in rawData) {
      if (item is! Map) {
        throw const ApiContractException('pickup.final_mile.item');
      }
      tasks.add(
        PickupTask.fromJson(
          Map<String, dynamic>.from(item),
          defaultLeg: PickupTaskLeg.finalMile,
        ),
      );
    }
    return tasks;
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    final response = await _client.get(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile.detail');
    return _taskFromData(payload, PickupTaskLeg.finalMile);
  }

  @override
  Future<PickupTask> acceptFinalMileTask(String taskId) async {
    final response = await _client.postJson(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}/accept',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile.accept');
    return _taskFromData(payload, PickupTaskLeg.finalMile);
  }

  @override
  Future<FinalMilePickupSubmission> submitFinalMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final response = await _client.postJson(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}/pickup',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'identifier_type': identifierType,
        'identifier': identifier.trim(),
        'expected_revision': expectedRevision,
      },
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile');
    return FinalMilePickupSubmission.fromResponse(payload);
  }

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
