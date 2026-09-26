import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/final_mile_batch_models.dart';

abstract interface class FinalMileBatchRepository {
  Future<List<FinalMileBatch>> fetchBatches();

  Future<FinalMileBatch> fetchBatch(String scheduleId);

  Future<FinalMileBatch> acceptBatch(String scheduleId);
}

class ApiFinalMileBatchRepository implements FinalMileBatchRepository {
  ApiFinalMileBatchRepository({required this.client});

  final ApiClient client;

  @override
  Future<List<FinalMileBatch>> fetchBatches() async {
    final response = await client.get(
      '/courier/final-mile-batches',
      authenticated: true,
    );
    final payload = _decode(response.body, 'batch.list');
    final data = payload['data'];
    if (data is! List || data.length > 30) {
      throw const ApiContractException('batch.list.data');
    }
    return List<FinalMileBatch>.unmodifiable(data.map(FinalMileBatch.fromJson));
  }

  @override
  Future<FinalMileBatch> fetchBatch(String scheduleId) async {
    final response = await client.get(
      '/courier/final-mile-batches/${_segment(scheduleId)}',
      authenticated: true,
    );
    return _batchFromResponse(response.body, 'batch.detail');
  }

  @override
  Future<FinalMileBatch> acceptBatch(String scheduleId) async {
    final response = await client.postJson(
      '/courier/final-mile-batches/${_segment(scheduleId)}/accept',
      authenticated: true,
    );
    return _batchFromResponse(response.body, 'batch.accept');
  }

  FinalMileBatch _batchFromResponse(String body, String field) {
    final payload = _decode(body, field);
    if (!payload.containsKey('data')) {
      throw ApiContractException('$field.data');
    }
    return FinalMileBatch.fromJson(payload['data']);
  }

  Map<String, dynamic> _decode(String body, String field) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      // Converted to a stable contract error below.
    }
    throw ApiContractException(field);
  }

  String _segment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const ApiContractException('batch.schedule_id');
    }
    return Uri.encodeComponent(trimmed);
  }
}
