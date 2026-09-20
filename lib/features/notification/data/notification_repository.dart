import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/notification_models.dart';

abstract interface class NotificationRepository {
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    int limit = 20,
    String? cursor,
  });

  Future<int> fetchUnreadCount();

  Future<CourierNotification> fetchDetail(String notificationId);

  Future<CourierNotification> markRead(String notificationId);
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository({required this._client});

  final ApiClient _client;

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    int limit = 20,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 20) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 20');
    }

    final normalizedCursor = cursor?.trim();
    final response = await _client.get(
      '/courier/notifications',
      authenticated: true,
      queryParameters: <String, String>{
        'status': filter.apiValue,
        'limit': '$limit',
        if (normalizedCursor != null && normalizedCursor.isNotEmpty)
          'cursor': normalizedCursor,
      },
    );
    final payload = _decodeObject(response.body, 'notification.list');
    final rawData = payload['data'];
    if (rawData is! List) {
      throw const ApiContractException('notification.list.data');
    }

    final items = <CourierNotification>[];
    for (final item in rawData) {
      if (item is! Map) {
        throw const ApiContractException('notification.list.item');
      }
      items.add(CourierNotification.fromJson(Map<String, dynamic>.from(item)));
    }

    final rawMeta = payload['meta'];
    if (rawMeta is! Map) {
      throw const ApiContractException('notification.list.meta');
    }
    final meta = Map<String, dynamic>.from(rawMeta);
    final nextCursor = _nullableString(
      meta['next_cursor'],
      'notification.list.next_cursor',
    );
    final generatedAt = _nullableDateTime(
      meta['generated_at'],
      'notification.list.generated_at',
    );

    return CourierNotificationPage(
      items: List<CourierNotification>.unmodifiable(items),
      nextCursor: nextCursor,
      generatedAt: generatedAt,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    final response = await _client.get(
      '/courier/notifications/unread-count',
      authenticated: true,
    );
    final payload = _decodeObject(response.body, 'notification.count');
    final rawData = payload['data'];
    if (rawData is! Map) {
      throw const ApiContractException('notification.count.data');
    }
    final value = Map<String, dynamic>.from(rawData)['unread_count'];
    if (value is! int || value < 0) {
      throw const ApiContractException('notification.count.unread_count');
    }
    return value;
  }

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async {
    final response = await _client.get(
      '/courier/notifications/${_pathSegment(notificationId)}',
      authenticated: true,
    );
    return _notificationFromEnvelope(response.body, 'notification.detail');
  }

  @override
  Future<CourierNotification> markRead(String notificationId) async {
    final response = await _client.postJson(
      '/courier/notifications/${_pathSegment(notificationId)}/read',
      authenticated: true,
      body: const <String, Object?>{},
    );
    return _notificationFromEnvelope(response.body, 'notification.read');
  }
}

CourierNotification _notificationFromEnvelope(String body, String field) {
  final payload = _decodeObject(body, field);
  final data = payload['data'];
  if (data is! Map) {
    throw ApiContractException('$field.data');
  }
  return CourierNotification.fromJson(Map<String, dynamic>.from(data));
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

String? _nullableString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ApiContractException(field);
  }
  return parsed.toUtc();
}

String _pathSegment(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'value', 'must not be empty');
  }
  return Uri.encodeComponent(normalized);
}
