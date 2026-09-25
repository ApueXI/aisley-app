import 'dart:convert';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reads the Courier inbox with leg, bounded limit and bearer', () async {
    late http.Request request;
    final repo = _repo((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_inbox), 200);
    });
    final page = await repo.list(leg: 'first_mile', limit: 20);
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/operational-conversations');
    expect(request.url.queryParameters, {'leg': 'first_mile', 'limit': '20'});
    expect(request.headers['authorization'], 'Bearer test-token');
    expect(page.items.single.taskId, 'task-1');
    expect(page.items.single.sendAllowed, isNull);
    expect(page.unreadCount, 1);
  });

  test(
    'reads detail, ascending message history, and committed read marker',
    () async {
      final requests = <http.Request>[];
      final repo = _repo((incoming) async {
        requests.add(incoming);
        if (incoming.url.path.endsWith('/messages')) {
          return http.Response(jsonEncode(_messages), 200);
        }
        return http.Response(jsonEncode({'data': _thread}), 200);
      });
      final thread = await repo.detail('thread-1');
      final history = await repo.messages(
        'thread-1',
        cursor: 'older',
        limit: 50,
      );
      final read = await repo.markRead('thread-1', 1);
      expect(thread.sendAllowed, isTrue);
      expect(history.items.single.body, 'Hello');
      expect(history.items.single.sequence, 1);
      expect(requests[1].url.queryParameters, {
        'cursor': 'older',
        'limit': '50',
      });
      expect(requests[2].method, 'POST');
      expect(jsonDecode(requests[2].body), {'last_read_sequence': 1});
      expect(requests[2].headers.containsKey('idempotency-key'), isFalse);
      expect(read.id, 'thread-1');
    },
  );

  test(
    'starts Seller chat and sends with exact JSON and distinct UUID keys',
    () async {
      final requests = <http.Request>[];
      final repo = _repo((incoming) async {
        requests.add(incoming);
        return http.Response(jsonEncode(_send), 201);
      });
      await repo.start(
        leg: 'first_mile',
        taskId: 'task-1',
        counterpartyRole: 'seller',
        body: 'Hello Seller',
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      );
      await repo.send(
        id: 'thread-1',
        body: 'Hello',
        idempotencyKey: '22222222-2222-4222-8222-222222222222',
      );
      expect(requests[0].url.path, '/api/v1/courier/operational-conversations');
      expect(jsonDecode(requests[0].body), {
        'leg': 'first_mile',
        'task_id': 'task-1',
        'counterparty_role': 'seller',
        'body': 'Hello Seller',
      });
      expect(
        requests[0].headers['idempotency-key'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(
        requests[1].url.path,
        '/api/v1/courier/operational-conversations/thread-1/messages',
      );
      expect(jsonDecode(requests[1].body), {'body': 'Hello'});
      expect(
        requests[1].headers['idempotency-key'],
        '22222222-2222-4222-8222-222222222222',
      );
    },
  );

  test(
    'rejects an incomplete successful response instead of empty chat',
    () async {
      final repo = _repo((_) async => http.Response('{"data":[]}', 200));
      await expectLater(repo.list(), throwsA(isA<ApiContractException>()));
    },
  );
}

ApiChatRepository _repo(Future<http.Response> Function(http.Request) handler) {
  return ApiChatRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _TokenStorage(),
      client: MockClient(handler),
    ),
  );
}

class _TokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => 'test-token';

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

const _thread = <String, dynamic>{
  'id': 'thread-1',
  'kind': 'logistics_courier',
  'leg': 'first_mile',
  'task_id': 'task-1',
  'task_reference': 'ORD-123',
  'counterparty_role': 'logistics',
  'counterparty_label': 'Logistics',
  'unread_count': 1,
  'last_sequence': 1,
  'last_read_sequence': 0,
  'send_allowed': true,
  'read_only_reason': null,
};

const _message = <String, dynamic>{
  'id': 'message-1',
  'conversation_id': 'thread-1',
  'sequence': 1,
  'sender_role': 'logistics',
  'mine': false,
  'body': 'Hello',
  'created_at': '2026-09-24T00:00:00Z',
};

const _inbox = <String, dynamic>{
  'data': [
    <String, dynamic>{
      'id': 'thread-1',
      'kind': 'logistics_courier',
      'leg': 'first_mile',
      'task_id': 'task-1',
      'counterparty_role': 'logistics',
      'unread_count': 1,
      'read_only_reason': null,
    },
  ],
  'meta': {'next_cursor': null, 'unread_count': 1},
};

const _messages = <String, dynamic>{
  'data': [_message],
  'meta': {'next_cursor': null},
};

const _send = <String, dynamic>{'conversation': _thread, 'message': _message};
