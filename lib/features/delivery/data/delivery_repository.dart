import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../pickup/domain/pickup_models.dart';
import '../domain/delivery_models.dart';

abstract interface class DeliveryRepository {
  Future<List<PickupTask>> fetchFinalMileTasks();

  Future<DeliveryContext> fetchDeliveryContext(String taskId);

  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
  });

  Future<ProofSubmission> submitProof({
    required String taskId,
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<CompletionProjection> fetchCompletion(String taskId);

  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
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
  }) async {
    final response = await _client.postJson(
      '/courier/final-mile-tasks/${_pathSegment(taskId)}/status',
      authenticated: true,
      body: <String, Object?>{
        'status': status,
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
    required String identifierType,
    required String identifier,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final response = await _client.postJson(
      '/courier/tasks/${_pathSegment(taskId)}/proof-of-delivery',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'identifier_type': identifierType,
        'identifier': identifier.trim(),
        'expected_revision': expectedRevision,
      },
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
  }) async {
    final response = await _client.postJson(
      '/courier/tasks/${_pathSegment(taskId)}/completion',
      authenticated: true,
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      body: <String, Object?>{
        'expected_revision': expectedRevision,
        'evidence_id': evidenceId,
        'confirmed': true,
      },
    );
    return CompletionProjection.fromResponse(
      _decodeObject(response.body, 'delivery.completion.submit'),
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
