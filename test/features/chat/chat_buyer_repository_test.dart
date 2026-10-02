import 'dart:convert';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Buyer start revalidates the exact final-mile task before posting',
    () async {
      final requests = <http.Request>[];
      final repo = _repo((request) async {
        requests.add(request);
        if (request.method == 'GET') return _task('out_for_delivery');
        return http.Response(jsonEncode(_result), 201);
      });
      final result = await _start(repo);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/courier/final-mile-tasks/task-1',
        '/api/v1/courier/operational-conversations',
      ]);
      expect(requests.first.headers['authorization'], 'Bearer test-token');
      expect(jsonDecode(requests.last.body), {
        'leg': 'final_mile',
        'task_id': 'task-1',
        'counterparty_role': 'customer',
        'body': 'At the entrance.',
      });
      expect(requests.last.headers['idempotency-key'], _key);
      expect(result.thread.counterpartyRole, 'customer');
    },
  );

  for (final status in [
    'delivery_accepted',
    'picked_up_from_hub',
    'in_transit',
  ]) {
    test('Buyer start permits accepted state $status', () async {
      final repo = _repo(
        (r) async => r.method == 'GET'
            ? _task(status)
            : http.Response(jsonEncode(_result), 201),
      );
      expect((await _start(repo)).thread.leg, 'final_mile');
    });
  }
  for (final status in [
    'delivery_assigned',
    'delivered',
    'rejected',
    'cancelled',
    'unknown',
  ]) {
    test('Buyer start blocks $status without a POST', () async {
      var requests = 0;
      final repo = _repo((r) async {
        requests++;
        return _task(status);
      });
      await expectLater(
        _start(repo),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'TASK_NOT_ACTIVE'),
        ),
      );
      expect(requests, 1);
    });
  }

  test(
    'wrong task or first-mile response cannot authorize Buyer start',
    () async {
      final wrongTask = _repo(
        (r) async => _task('out_for_delivery', id: 'other'),
      );
      await expectLater(
        _start(wrongTask),
        throwsA(isA<ApiContractException>()),
      );
      final wrongLeg = _repo((r) async => _task('accepted', leg: 'first_mile'));
      await expectLater(_start(wrongLeg), throwsA(isA<ApiException>()));
    },
  );
  test('offline preflight does not post or use counterpart routes', () async {
    final requests = <http.Request>[];
    final repo = _repo((r) async {
      requests.add(r);
      throw http.ClientException('offline');
    });
    await expectLater(_start(repo), throwsA(isA<ApiException>()));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/v1/courier/final-mile-tasks/task-1');
  });
  test(
    'Buyer send, history and read use only the existing Courier routes',
    () async {
      final requests = <http.Request>[];
      final repo = _repo((r) async {
        requests.add(r);
        if (r.method == 'GET' && r.url.path.endsWith('/messages')) {
          return http.Response(
            jsonEncode({
              'data': [_message],
              'meta': {'next_cursor': null},
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/read')) {
          return http.Response(jsonEncode({'data': _thread}), 200);
        }
        return http.Response(jsonEncode(_result), 201);
      });
      await repo.send(
        id: 'thread-1',
        body: 'At the entrance.',
        idempotencyKey: _key,
      );
      final history = await repo.messages('thread-1', limit: 50);
      await repo.markRead('thread-1', 1);
      expect(history.items.single.senderRole, 'customer');
      expect(
        requests.every(
          (r) => r.url.path.startsWith(
            '/api/v1/courier/operational-conversations/',
          ),
        ),
        isTrue,
      );
      expect(jsonDecode(requests.first.body), {'body': 'At the entrance.'});
      expect(requests.first.headers['idempotency-key'], _key);
      expect(jsonDecode(requests.last.body), {'last_read_sequence': 1});
      expect(requests.last.headers.containsKey('idempotency-key'), isFalse);
    },
  );
}

const _key = '11111111-1111-4111-8111-111111111111';
Future<ChatSendResult> _start(ApiChatRepository repo) => repo.start(
  leg: 'final_mile',
  taskId: 'task-1',
  counterpartyRole: 'customer',
  body: 'At the entrance.',
  idempotencyKey: _key,
);
http.Response _task(
  String status, {
  String id = 'task-1',
  String leg = 'final_mile',
}) => http.Response(
  jsonEncode({
    'data': {'task_id': id, 'leg': leg, 'status': status, 'revision': 4},
  }),
  200,
);
ApiChatRepository _repo(Future<http.Response> Function(http.Request) handler) =>
    ApiChatRepository(
      client: ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example.test'),
        tokenStorage: _TokenStorage(),
        client: MockClient(handler),
      ),
    );

class _TokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => 'test-token';
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(String value) async {}
}

const _thread = {
  'id': 'thread-1',
  'kind': 'courier_customer',
  'leg': 'final_mile',
  'task_id': 'task-1',
  'counterparty_role': 'customer',
  'counterparty_label': 'Buyer',
  'unread_count': 0,
  'last_sequence': 1,
  'last_read_sequence': 0,
  'send_allowed': true,
};
const _message = {
  'id': 'message-1',
  'conversation_id': 'thread-1',
  'sequence': 1,
  'sender_role': 'customer',
  'mine': false,
  'body': 'At the entrance.',
  'created_at': '2026-10-02T00:00:00Z',
};
const _result = {'conversation': _thread, 'message': _message};
