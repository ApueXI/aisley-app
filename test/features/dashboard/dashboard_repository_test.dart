import 'dart:convert';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reads the protected scaffold without query or mutation', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_scaffold), 200);
    });

    final snapshot = await repository.fetchDashboard();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/dashboard');
    expect(request.url.query, isEmpty);
    expect(request.headers['authorization'], 'Bearer test-token');
    expect(snapshot.freshness.state, DashboardFreshnessState.scaffold);
    expect(
      snapshot.section('available_tasks').state,
      DashboardSectionState.unavailable,
    );
  });

  for (final field in [
    'data',
    'meta',
    'sections.available_tasks',
    'freshness',
  ]) {
    test('rejects malformed $field rather than showing empty work', () async {
      final response = Map<String, dynamic>.from(_scaffold);
      switch (field) {
        case 'data':
          response['data'] = <String>['unexpected task'];
        case 'meta':
          response['meta'] = <String, dynamic>{'next_cursor': 'unexpected'};
        case 'sections.available_tasks':
          response['sections'] = <String, dynamic>{
            ...(_scaffold['sections'] as Map<String, dynamic>),
            'available_tasks': <String, dynamic>{'state': 'empty'},
          };
        case 'freshness':
          response['freshness'] = <String, dynamic>{'state': 'fresh'};
      }
      final repository = _repository(
        (_) async => http.Response(jsonEncode(response), 200),
      );

      await expectLater(
        repository.fetchDashboard(),
        throwsA(isA<ApiContractException>()),
      );
    });
  }
}

ApiDashboardRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiDashboardRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage(),
      client: MockClient(handler),
    ),
  );
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => 'test-token';

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}

const _scaffold = <String, dynamic>{
  'data': <dynamic>[],
  'meta': <String, dynamic>{'next_cursor': null, 'generated_at': 'server-time'},
  'sections': <String, dynamic>{
    'notifications': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
    'available_tasks': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
    'active_tasks': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
  },
  'freshness': <String, dynamic>{
    'state': 'scaffold',
    'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    'generated_at': 'server-time',
  },
};
