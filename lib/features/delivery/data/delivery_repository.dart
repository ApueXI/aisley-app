import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/networking/multipart_file_selection.dart';
import '../../pickup/domain/pickup_models.dart';
import '../domain/delivery_models.dart';

abstract interface class DeliveryRepository {
  Future<List<PickupTask>> fetchFinalMileTasks();

  Future<PickupTask> fetchFinalMileTask(String taskId);

  Future<DeliveryContext> fetchDeliveryContext(String taskId);

  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  });

  Future<CompletionProjection> fetchCompletion(String taskId);

  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
    required bool codCollected,
  });
}

class ApiDeliveryRepository implements DeliveryRepository {
  ApiDeliveryRepository({required this._client});

  final ApiClient _client;

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    final response = await _client.get(
      '/courier/final-mile-tasks',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'delivery.tasks');
    final rawData = payload['data'];
    if (rawData is! List) {
      throw const ApiContractException('delivery.tasks.data');
    }
    return rawData
        .map<PickupTask>((item) {
          if (item is! Map) {
            throw const ApiContractException('delivery.tasks.item');
          }
          return PickupTask.fromJson(
            Map<String, dynamic>.from(item),
            defaultLeg: PickupTaskLeg.finalMile,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    final response = await _client.get(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'delivery.task');
    final rawData = payload['data'];
    if (rawData is! Map) {
      throw const ApiContractException('delivery.task.data');
    }
    return PickupTask.fromJson(
      Map<String, dynamic>.from(rawData),
      defaultLeg: PickupTaskLeg.finalMile,
    );
  }

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    final response = await _client.get(
      '/courier/tasks/${_pathSegment(taskId)}/delivery',
      authenticated: true,
    );
    return DeliveryContext.fromResponse(
      _decodeObject(response.body, 'delivery.context'),
    );
  }

  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final response = await _client.postJson(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}/status',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'target_state': status,
        'expected_revision': expectedRevision,
      },
    );
    return DeliveryStatusUpdate.fromResponse(
      _decodeObject(response.body, 'delivery.status'),
    );
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    final response = await _client.postMultipart(
      '/courier/tasks/${_pathSegment(taskId)}/proof-of-delivery',
      authenticated: true,
      requestHeaders: <String, String>{'Idempotency-Key': idempotencyKey},
      fields: <String, String>{'expected_revision': '$expectedRevision'},
      files: <String, MultipartFileSelection>{
        'photo': MultipartFileSelection(
          path: photo.path,
          fileName: photo.fileName,
          bytes: photo.bytes,
        ),
      },
      onCancel: onCancel,
    );
    return ProofSubmission.fromResponse(
      _decodeObject(response.body, 'delivery.proof'),
    );
  }

  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async {
    final response = await _client.get(
      '/courier/tasks/${_pathSegment(taskId)}/completion',
      authenticated: true,
    );
    return CompletionProjection.fromResponse(
      _decodeObject(response.body, 'delivery.completion'),
    );
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
    required bool codCollected,
  }) async {
    final response = await _client.postJson(
      '/courier/tasks/${_pathSegment(taskId)}/completion',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'expected_revision': expectedRevision,
        'evidence_id': evidenceId,
        'confirmed': true,
        if (codCollected) 'cod_collected': true,
      },
    );
    try {
      return CompletionProjection.fromResponse(
        _decodeObject(response.body, 'delivery.completion.submit'),
      );
    } on ApiContractException {
      // A successful 202 acknowledges the intent, while the completion GET
      // is the authoritative projection. Recover from an empty or differently
      // serialized acknowledgment without treating it as delivery success.
      if (response.statusCode == 202) {
        return fetchCompletion(taskId);
      }
      rethrow;
    }
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
