part of '../pickup_repository.dart';

class _FirstMilePickupRepository {
  _FirstMilePickupRepository({required this.client});

  final ApiClient client;

  Future<FirstMileTaskPage> fetchTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    if (perPage < 1 || perPage > 50) {
      throw ArgumentError.value(perPage, 'perPage', 'must be between 1 and 50');
    }

    final normalizedSchedule = pickupScheduleId?.trim();
    final response = await client.get(
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

  Future<PickupTask> acceptTask(String taskId) async {
    final response = await client.postJson(
      '/courier/first-mile-tasks/${_pathSegment(taskId)}/accept',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.first_mile.accept');
    return _taskFromData(payload, PickupTaskLeg.firstMile);
  }

  Future<WaybillResolution> resolveWaybill(String payload) async {
    final normalizedPayload = payload.trim();
    if (normalizedPayload.isEmpty || normalizedPayload.length > 128) {
      throw const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'The waybill QR payload is invalid.',
      );
    }

    final response = await client.postJson(
      '/courier/waybills/resolve',
      authenticated: true,
      body: <String, Object?>{'payload': normalizedPayload},
    );
    final decoded = _decodeObject(response.body, 'pickup.resolve');
    return WaybillResolution.fromResponse(decoded);
  }

  Future<FirstMilePickupResult> confirmPickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required String idempotencyKey,
  }) async {
    final response = await client.postJson(
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

  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId) async {
    final response = await client.get(
      '/courier/pickup-schedules/${_pathSegment(scheduleId)}/route-manifest',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.manifest');
    return PickupRouteManifest.fromResponse(payload);
  }
}
