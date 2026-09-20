import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';

void main() {
  test('lists notifications with the documented filter and cursor', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_listResponse), 200);
    });

    final page = await repository.fetchNotifications(
      filter: NotificationFilter.unread,
      limit: 20,
      cursor: 'signed-cursor',
    );

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/notifications');
    expect(request.url.queryParameters, <String, String>{
      'status': 'unread',
      'limit': '20',
      'cursor': 'signed-cursor',
    });
    expect(request.headers['authorization'], 'Bearer notification-token');
    expect(page.items.single.id, 'notification-1');
    expect(page.items.single.isRead, isFalse);
    expect(page.nextCursor, 'next-cursor');
    expect(page.generatedAt, isNotNull);
  });

  test('reads unread count from the dedicated endpoint', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode(const <String, dynamic>{
          'data': <String, dynamic>{'unread_count': 3},
        }),
        200,
      );
    });

    expect(await repository.fetchUnreadCount(), 3);
    expect(request.url.path, '/api/v1/courier/notifications/unread-count');
    expect(request.headers['authorization'], 'Bearer notification-token');
  });

  test(
    'reads detail without changing read state and marks read explicitly',
    () async {
      final requests = <http.Request>[];
      final repository = _repository((incoming) async {
        requests.add(incoming);
        return http.Response(jsonEncode(_readResponse), 200);
      });

      final detail = await repository.fetchDetail('notification-1');
      final marked = await repository.markRead('notification-1');

      expect(detail.id, 'notification-1');
      expect(marked.readAt, isNotNull);
      expect(requests[0].method, 'GET');
      expect(
        requests[0].url.path,
        '/api/v1/courier/notifications/notification-1',
      );
      expect(requests[1].method, 'POST');
      expect(
        requests[1].url.path,
        '/api/v1/courier/notifications/notification-1/read',
      );
      expect(jsonDecode(requests[1].body), <String, dynamic>{});
      expect(requests[1].headers['authorization'], 'Bearer notification-token');
    },
  );

  test('rejects an invalid notification envelope', () async {
    final repository = _repository((incoming) async {
      return http.Response(
        jsonEncode(const <String, dynamic>{'data': <dynamic>[]}),
        200,
      );
    });

    expect(
      () => repository.fetchUnreadCount(),
      throwsA(
        isA<ApiContractException>().having(
          (error) => error.field,
          'field',
          'notification.count.data',
        ),
      ),
    );
  });
}

ApiNotificationRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiNotificationRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'notification-token',
      client: MockClient(handler),
    ),
  );
}

class _FakeTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

const _listResponse = <String, dynamic>{
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'notification-1',
      'type': 'courier-task.final-mile-offered',
      'title': 'Delivery offered',
      'summary': 'A delivery request is available.',
      'read_at': null,
      'created_at': '2026-09-20T02:00:00Z',
      'resource_type': 'delivery_task',
      'resource_id': 'task-1',
      'destination': '/delivery-tasks/task-1',
    },
  ],
  'meta': <String, dynamic>{
    'next_cursor': 'next-cursor',
    'generated_at': '2026-09-20T02:00:01Z',
  },
};

const _readResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'id': 'notification-1',
    'type': 'courier-task.final-mile-offered',
    'title': 'Delivery offered',
    'summary': 'A delivery request is available.',
    'read_at': '2026-09-20T02:01:00Z',
    'created_at': '2026-09-20T02:00:00Z',
    'resource_type': 'delivery_task',
    'resource_id': 'task-1',
    'destination': '/delivery-tasks/task-1',
  },
};
