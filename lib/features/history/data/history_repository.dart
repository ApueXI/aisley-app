import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/history_models.dart';

abstract interface class HistoryRepository {
  Future<DeliveryHistoryPage> fetchHistory({String? reference, int limit = 20});

  Future<DeliveryHistoryItem> fetchDetail(String taskId);
}

class ApiHistoryRepository implements HistoryRepository {
  ApiHistoryRepository({required this._client});

  final ApiClient _client;

  @override
  Future<DeliveryHistoryPage> fetchHistory({
    String? reference,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 50');
    }
    final normalizedReference = reference?.trim();
    final response = await _client.get(
      '/courier/delivery-history',
      authenticated: true,
      queryParameters: <String, String>{
        'limit': '$limit',
        if (normalizedReference != null && normalizedReference.isNotEmpty)
          'reference': normalizedReference,
      },
    );
    final payload = _decodeObject(response.body, 'history.list');
    final rawData = payload['data'];
    if (rawData is! List) {
      throw const ApiContractException('history.data');
    }
    final itemsByTask = <String, DeliveryHistoryItem>{};
    for (final item in rawData) {
      if (item is! Map) {
        throw const ApiContractException('history.row');
      }
      final historyItem = DeliveryHistoryItem.fromJson(
        Map<String, dynamic>.from(item),
      );
      itemsByTask.putIfAbsent(historyItem.taskId, () => historyItem);
    }
    final rawMeta = payload['meta'];
    final meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : const <String, dynamic>{};
    return DeliveryHistoryPage(
      items: List<DeliveryHistoryItem>.unmodifiable(itemsByTask.values),
      hasMore: meta['has_more'] == true,
      nextCursor: meta['next_cursor']?.toString(),
    );
  }

  @override
  Future<DeliveryHistoryItem> fetchDetail(String taskId) async {
    final response = await _client.get(
      '/courier/delivery-history/${_pathSegment(taskId)}',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'history.detail');
    final data = payload['data'];
    if (data is! Map) {
      throw const ApiContractException('history.detail.data');
    }
    return DeliveryHistoryItem.fromJson(Map<String, dynamic>.from(data));
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
