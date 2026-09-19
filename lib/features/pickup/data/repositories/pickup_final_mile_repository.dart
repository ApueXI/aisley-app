part of '../pickup_repository.dart';

class _FinalMilePickupRepository {
  _FinalMilePickupRepository({required this.client});

  final ApiClient client;

  Future<List<PickupTask>> fetchTasks() async {
    final response = await client.get(
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

  Future<PickupTask> fetchTask(String taskId) async {
    final response = await client.get(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile.detail');
    return _taskFromData(payload, PickupTaskLeg.finalMile);
  }

  Future<PickupTask> acceptTask(String taskId) async {
    final response = await client.postJson(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}/accept',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile.accept');
    return _taskFromData(payload, PickupTaskLeg.finalMile);
  }

  Future<FinalMileRejectionResult> rejectTask({
    required String taskId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await client.postJson(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}/reject',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{'reason': reason.trim()},
    );
    final payload = _decodeObject(response.body, 'pickup.final_mile.reject');
    return FinalMileRejectionResult.fromResponse(payload);
  }

  Future<FinalMilePickupSubmission> submitPickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final response = await client.postJson(
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
}
