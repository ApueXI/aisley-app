import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/chat_models.dart';

abstract interface class ChatRepository {
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  });
  Future<ChatThread> detail(String id);
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  });
  Future<ChatSendResult> start({
    required String leg,
    required String taskId,
    required String counterpartyRole,
    required String body,
    required String idempotencyKey,
  });
  Future<ChatSendResult> send({
    required String id,
    required String body,
    required String idempotencyKey,
  });
  Future<ChatThread> markRead(String id, int lastReadSequence);
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository({required this._client});

  static const _base = '/courier/operational-conversations';
  final ApiClient _client;

  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async {
    _checkPage(limit);
    if (leg != null && !chatLegs.contains(leg)) {
      throw ArgumentError.value(leg, 'leg');
    }
    final response = await _client.get(
      _base,
      authenticated: true,
      queryParameters: {
        'limit': '$limit',
        'leg': ?leg,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final payload = _decode(response.body, 'chat.list');
    return _page(payload, 'chat.list', ChatThread.fromJson, withUnread: true);
  }

  @override
  Future<ChatThread> detail(String id) async {
    final response = await _client.get(
      '$_base/${_segment(id)}',
      authenticated: true,
    );
    return _threadEnvelope(response.body, 'chat.detail');
  }

  @override
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    _checkPage(limit);
    final response = await _client.get(
      '$_base/${_segment(id)}/messages',
      authenticated: true,
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return _page(
      _decode(response.body, 'chat.messages'),
      'chat.messages',
      ChatMessage.fromJson,
    );
  }

  @override
  Future<ChatSendResult> start({
    required String leg,
    required String taskId,
    required String counterpartyRole,
    required String body,
    required String idempotencyKey,
  }) async {
    if (!chatLegs.contains(leg) || !chatRoles.contains(counterpartyRole)) {
      throw ArgumentError('Invalid chat context');
    }
    final response = await _client.postJson(
      _base,
      authenticated: true,
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'leg': leg,
        'task_id': taskId,
        'counterparty_role': counterpartyRole,
        'body': body,
      },
    );
    return _sendEnvelope(response.body, 'chat.start');
  }

  @override
  Future<ChatSendResult> send({
    required String id,
    required String body,
    required String idempotencyKey,
  }) async {
    final response = await _client.postJson(
      '$_base/${_segment(id)}/messages',
      authenticated: true,
      headers: {'Idempotency-Key': idempotencyKey},
      body: {'body': body},
    );
    return _sendEnvelope(response.body, 'chat.send');
  }

  @override
  Future<ChatThread> markRead(String id, int lastReadSequence) async {
    if (lastReadSequence < 0) throw ArgumentError.value(lastReadSequence);
    final response = await _client.postJson(
      '$_base/${_segment(id)}/read',
      authenticated: true,
      body: {'last_read_sequence': lastReadSequence},
    );
    return _threadEnvelope(response.body, 'chat.read');
  }
}

ChatPage<T> _page<T>(
  Map<String, dynamic> payload,
  String field,
  T Function(Map<String, dynamic>) parse, {
  bool withUnread = false,
}) {
  final data = payload['data'];
  final meta = payload['meta'];
  if (data is! List || meta is! Map || !meta.containsKey('next_cursor')) {
    throw ApiContractException(field);
  }
  final cursor = meta['next_cursor'];
  if (cursor != null && (cursor is! String || cursor.isEmpty)) {
    throw ApiContractException('$field.next_cursor');
  }
  final unread = meta['unread_count'];
  if (withUnread && (unread is! int || unread < 0)) {
    throw ApiContractException('$field.unread_count');
  }
  final items = <T>[];
  for (final row in data) {
    if (row is! Map) throw ApiContractException('$field.item');
    items.add(parse(Map<String, dynamic>.from(row)));
  }
  return ChatPage<T>(
    items: List.unmodifiable(items),
    nextCursor: cursor as String?,
    unreadCount: withUnread ? unread as int : null,
  );
}

ChatThread _threadEnvelope(String body, String field) {
  final data = _decode(body, field)['data'];
  if (data is! Map) throw ApiContractException('$field.data');
  return ChatThread.fromJson(Map<String, dynamic>.from(data));
}

ChatSendResult _sendEnvelope(String body, String field) {
  final payload = _decode(body, field);
  final thread = payload['conversation'];
  final message = payload['message'];
  if (thread is! Map || message is! Map) throw ApiContractException(field);
  final parsedThread = ChatThread.fromJson(Map<String, dynamic>.from(thread));
  final parsedMessage = ChatMessage.fromJson(
    Map<String, dynamic>.from(message),
  );
  if (parsedThread.id != parsedMessage.conversationId) {
    throw ApiContractException('$field.conversation_id');
  }
  return ChatSendResult(thread: parsedThread, message: parsedMessage);
}

Map<String, dynamic> _decode(String body, String field) {
  try {
    final result = jsonDecode(body);
    if (result is Map) return Map<String, dynamic>.from(result);
  } on FormatException {
    // A successful response must still match the documented DTO.
  }
  throw ApiContractException(field);
}

String _segment(String id) {
  if (id.trim().isEmpty) throw ArgumentError.value(id);
  return Uri.encodeComponent(id);
}

void _checkPage(int limit) {
  if (limit < 1 || limit > 50) throw ArgumentError.value(limit);
}
