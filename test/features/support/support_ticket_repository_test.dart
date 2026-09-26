import 'dart:convert';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/support/data/support_ticket_repository.dart';
import 'package:aisley_app/features/support/domain/support_ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('lists own tickets with opaque cursor and documented filters', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'items': [
            {..._summaryJson, 'category': 'future_category', 'status': 'new'},
          ],
          'next_cursor': 'opaque-next',
        }),
        200,
      );
    });

    final page = await repository.list(
      status: SupportTicketStatusFilter.open,
      category: SupportTicketCategoryFilter.delivery,
      cursor: 'opaque-cursor',
      limit: 25,
    );

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/support-tickets');
    expect(request.url.queryParameters, {
      'status': 'open',
      'category': 'delivery',
      'cursor': 'opaque-cursor',
      'limit': '25',
    });
    expect(request.headers['authorization'], 'Bearer test-token');
    expect(page.nextCursor, 'opaque-next');
    expect(page.items.single.categoryLabel, 'Other');
    expect(page.items.single.statusLabel, 'Status unavailable');
  });

  test('sends exact create, reply, and monotonic read requests', () async {
    final requests = <http.Request>[];
    final repository = _repository((incoming) async {
      requests.add(incoming);
      if (incoming.url.path.endsWith('/read')) {
        return http.Response(jsonEncode({'data': _summaryJson}), 200);
      }
      return http.Response(
        jsonEncode({'data': _summaryJson, 'event': _eventJson}),
        201,
      );
    });

    await repository.create(
      subject: 'Task help',
      category: 'delivery',
      body: 'Please review this issue.',
      idempotencyKey: '11111111-1111-4111-8111-111111111111',
    );
    await repository.reply(
      ticketId: 'ticket-1',
      body: 'More details',
      expectedRevision: 3,
      idempotencyKey: '22222222-2222-4222-8222-222222222222',
    );
    await repository.markRead(ticketId: 'ticket-1', lastReadSequence: 4);

    expect(jsonDecode(requests[0].body), {
      'subject': 'Task help',
      'category': 'delivery',
      'body': 'Please review this issue.',
    });
    expect(
      requests[0].headers['idempotency-key'],
      '11111111-1111-4111-8111-111111111111',
    );
    expect(
      requests[1].url.path,
      '/api/v1/courier/support-tickets/ticket-1/replies',
    );
    expect(jsonDecode(requests[1].body), {
      'body': 'More details',
      'expected_revision': 3,
    });
    expect(
      requests[1].headers['idempotency-key'],
      '22222222-2222-4222-8222-222222222222',
    );
    expect(jsonDecode(requests[2].body), {'last_read_sequence': 4});
    expect(requests[2].headers.containsKey('idempotency-key'), isFalse);
  });

  test('parses minimal detail and preserves server event order', () async {
    final repository = _repository((_) async {
      return http.Response(
        jsonEncode({
          'data': {
            'id': 'ticket-1',
            'reference': 'SUP-0001',
            'status': 'open',
            'revision': 3,
          },
          'events': [
            {..._eventJson, 'id': 'event-1', 'sequence': 1},
            {..._eventJson, 'id': 'event-2', 'sequence': 2},
          ],
          'next_cursor': null,
        }),
        200,
      );
    });

    final detail = await repository.detail('ticket-1', limit: 20);

    expect(detail.ticket.subject, isNull);
    expect(detail.ticket.revision, 3);
    expect(detail.events.map((event) => event.sequence), [1, 2]);
  });

  test('rejects private identity fields in a successful response', () async {
    final repository = _repository((_) async {
      return http.Response(
        jsonEncode({
          'items': [
            {..._summaryJson, 'assignee_id': 'private-admin-id'},
          ],
          'next_cursor': null,
        }),
        200,
      );
    });

    await expectLater(repository.list(), throwsA(isA<ApiContractException>()));
  });
}

ApiSupportTicketRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiSupportTicketRepository(
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

const _summaryJson = <String, dynamic>{
  'id': 'ticket-1',
  'reference': 'SUP-0001',
  'subject': 'Task help',
  'category': 'delivery',
  'status': 'open',
  'revision': 3,
  'requester_role': 'courier',
  'requester_name': null,
  'assignee_name': null,
  'assignee_id': null,
  'unread_count': 2,
  'last_activity_at': '2026-09-27T01:00:00Z',
  'created_at': '2026-09-27T00:00:00Z',
  'resolved_at': null,
};

const _eventJson = <String, dynamic>{
  'id': 'event-1',
  'sequence': 1,
  'type': 'reply',
  'actor_role': 'courier',
  'is_mine': true,
  'body': 'Please review this issue.',
  'from_status': null,
  'to_status': null,
  'assignment_changed': false,
  'created_at': '2026-09-27T00:00:00Z',
};
