import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/history/data/history_repository.dart';

void main() {
  test('reads private delivered history with the documented query', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_historyResponse), 200);
    });

    final page = await repository.fetchHistory(
      reference: 'ORDER-EXAMPLE',
      limit: 20,
    );

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/delivery-history');
    expect(request.url.queryParameters, <String, String>{
      'reference': 'ORDER-EXAMPLE',
      'limit': '20',
    });
    expect(request.headers['authorization'], 'Bearer history-token');
    expect(page.items.single.taskId, 'delivery-task-1');
    expect(page.items.single.status, 'delivered');
    expect(page.items.single.itemCount, 2);
    expect(page.items.single.pickupArea?.areaSummary, 'Makati City');
    expect(page.hasMore, isFalse);
  });

  test('reads one history record without exposing a writable action', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': (_historyResponse['data'] as List).single,
        }),
        200,
      );
    });

    final item = await repository.fetchDetail('delivery-task-1');

    expect(request.method, 'GET');
    expect(
      request.url.path,
      '/api/v1/courier/delivery-history/delivery-task-1',
    );
    expect(item.order?.reference, 'ORDER-EXAMPLE');
    expect(item.evidenceId, 'evidence-uuid');
  });
}

ApiHistoryRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiHistoryRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'history-token',
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

const _historyResponse = <String, dynamic>{
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'task_id': 'delivery-task-1',
      'leg': 'final_mile',
      'order': <String, dynamic>{
        'id': 'order-uuid',
        'reference': 'ORDER-EXAMPLE',
        'status': 'delivered',
      },
      'status': 'delivered',
      'delivered_at': '2026-09-11T08:00:00Z',
      'pickup_area': <String, dynamic>{'city_municipality': 'Makati City'},
      'destination_area': <String, dynamic>{
        'city_municipality': 'Pasig City',
        'region': 'NCR',
      },
      'parcel': <String, dynamic>{
        'id': 'parcel-uuid',
        'reference': 'PARCEL-EXAMPLE',
        'item_count': 2,
      },
      'evidence_status': 'validated',
      'completion_status': 'validated',
      'evidence_id': 'evidence-uuid',
    },
  ],
  'meta': <String, dynamic>{'next_cursor': null, 'has_more': false},
};
