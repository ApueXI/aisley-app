import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/pickup_models.dart';

part 'repositories/pickup_first_mile_repository.dart';
part 'repositories/pickup_final_mile_repository.dart';
part 'repositories/pickup_repository_helpers.dart';

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

  Future<FinalMileRejectionResult> rejectFinalMileTask({
    required String taskId,
    required String reason,
    required String idempotencyKey,
  });

  Future<FinalMilePickupSubmission> submitFinalMilePickup({
    required String taskId,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

class ApiPickupRepository implements PickupRepository {
  ApiPickupRepository({required this._client}) {
    _firstMile = _FirstMilePickupRepository(client: _client);
    _finalMile = _FinalMilePickupRepository(client: _client);
  }

  final ApiClient _client;
  late final _FirstMilePickupRepository _firstMile;
  late final _FinalMilePickupRepository _finalMile;

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) {
    return _firstMile.fetchTasks(
      pickupScheduleId: pickupScheduleId,
      perPage: perPage,
    );
  }

  @override
  Future<PickupTask> acceptFirstMileTask(String taskId) {
    return _firstMile.acceptTask(taskId);
  }

  @override
  Future<WaybillResolution> resolveWaybill(String payload) {
    return _firstMile.resolveWaybill(payload);
  }

  @override
  Future<FirstMilePickupResult> confirmFirstMilePickup({
    required String taskId,
    required String identifierType,
    required String identifier,
    required String idempotencyKey,
  }) {
    return _firstMile.confirmPickup(
      taskId: taskId,
      identifierType: identifierType,
      identifier: identifier,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId) {
    return _firstMile.fetchRouteManifest(scheduleId);
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() {
    return _finalMile.fetchTasks();
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) {
    return _finalMile.fetchTask(taskId);
  }

  @override
  Future<PickupTask> acceptFinalMileTask(String taskId) {
    return _finalMile.acceptTask(taskId);
  }

  @override
  Future<FinalMileRejectionResult> rejectFinalMileTask({
    required String taskId,
    required String reason,
    required String idempotencyKey,
  }) {
    return _finalMile.rejectTask(
      taskId: taskId,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<FinalMilePickupSubmission> submitFinalMilePickup({
    required String taskId,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    return _finalMile.submitPickup(
      taskId: taskId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }
}
