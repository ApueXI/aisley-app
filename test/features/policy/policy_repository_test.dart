import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';

void main() {
  test('fetches a public current policy without a bearer token', () async {
    late http.Request request;
    final storage = _FakeTokenStorage()..token = 'must-not-be-used';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_currentResponse), 200);
      }),
    );

    final document = await ApiPolicyRepository(client: client)
        .fetchCurrent(PolicyType.termsOfService);

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/platform/policies/terms_of_service');
    expect(request.headers['authorization'], isNull);
    expect(document.type, PolicyType.termsOfService);
    expect(document.version.version, 3);
    expect(document.version.content, contains('platform terms'));
  });

  test('uses the exact public history and historical version paths', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage(),
      client: MockClient((incoming) async {
        requests.add(incoming);
        if (incoming.url.path.endsWith('/history')) {
          return http.Response(jsonEncode(_historyResponse), 200);
        }
        return http.Response(jsonEncode(_privacyHistoryVersionResponse), 200);
      }),
    );
    final repository = ApiPolicyRepository(client: client);

    final history = await repository.fetchHistory(PolicyType.privacyPolicy);
    final document = await repository.fetchHistoryVersion(
      PolicyType.privacyPolicy,
      2,
    );

    expect(
      requests[0].url.path,
      '/api/v1/platform/policies/privacy_policy/history',
    );
    expect(
      requests[1].url.path,
      '/api/v1/platform/policies/privacy_policy/history/2',
    );
    expect(history.versions.single.version, 2);
    expect(document.version.version, 2);
  });

  test('reads private status with bearer auth and no request body', () async {
    late http.Request request;
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'policy-token',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_statusResponse), 200);
      }),
    );

    final status = await ApiPolicyRepository(client: client)
        .fetchConsentStatus();

    expect(request.url.path, '/api/v1/policy-consent/status');
    expect(request.headers['authorization'], 'Bearer policy-token');
    expect(request.body, isEmpty);
    expect(status.itemFor(PolicyType.termsOfService)?.currentVersion, 3);
    expect(status.allRequiredAccepted, isFalse);
  });

  test('reads a direct private status DTO when the envelope is omitted', () async {
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'policy-token',
      client: MockClient((incoming) async {
        return http.Response(jsonEncode(_directStatusResponse), 200);
      }),
    );

    final status = await ApiPolicyRepository(client: client)
        .fetchConsentStatus();

    expect(status.itemFor(PolicyType.termsOfService)?.currentVersion, 3);
    expect(status.allRequiredAccepted, isFalse);
  });

  test('does not cache private status responses', () async {
    var requestCount = 0;
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'policy-token',
      client: MockClient((incoming) async {
        requestCount += 1;
        return http.Response(jsonEncode(_statusResponse), 200);
      }),
    );
    final repository = ApiPolicyRepository(client: client);

    await repository.fetchConsentStatus();
    await repository.fetchConsentStatus();

    expect(requestCount, 2);
  });

  test(
    'accepts the exact current version with only confirmation true',
    () async {
      late http.Request request;
      final client = ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example.test'),
        tokenStorage: _FakeTokenStorage()..token = 'policy-token',
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(jsonEncode(_acceptanceResponse), 200);
        }),
      );

      final acceptance = await ApiPolicyRepository(client: client)
          .accept(type: PolicyType.termsOfService, version: 3);

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/policy-consent/terms_of_service/versions/3/accept',
      );
      expect(request.headers['authorization'], 'Bearer policy-token');
      expect(jsonDecode(request.body), <String, dynamic>{'confirmation': true});
      expect(acceptance.version.version, 3);
    },
  );

  test(
    'caches public current reads but force refresh bypasses the cache',
    () async {
      var requestCount = 0;
      final client = ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example.test'),
        tokenStorage: _FakeTokenStorage(),
        client: MockClient((incoming) async {
          requestCount += 1;
          return http.Response(jsonEncode(_currentResponse), 200);
        }),
      );
      final repository = ApiPolicyRepository(client: client);

      await repository.fetchCurrent(PolicyType.termsOfService);
      await repository.fetchCurrent(PolicyType.termsOfService);
      await repository.fetchCurrent(
        PolicyType.termsOfService,
        forceRefresh: true,
      );

      expect(requestCount, 2);
    },
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

const _versionJson = <String, dynamic>{
  'id': 'version-3',
  'version': 3,
  'title': 'Current policy',
  'content': 'These are the platform terms.',
  'status': 'published',
  'change_summary': 'Updated courier obligations.',
  'requires_reconsent': true,
  'published_at': '2026-09-10T08:00:00Z',
};

const _currentResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'type': 'terms_of_service',
    'label': 'Terms of Service',
    'version': _versionJson,
  },
};

const _privacyHistoryVersionResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'type': 'privacy_policy',
    'label': 'Privacy Policy',
    'version': <String, dynamic>{
      'id': 'version-2',
      'version': 2,
      'title': 'Previous privacy policy',
      'content': 'Previous privacy content.',
      'status': 'superseded',
      'change_summary': null,
      'requires_reconsent': false,
      'published_at': '2026-08-01T08:00:00Z',
    },
  },
};

const _historyResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'type': 'privacy_policy',
    'label': 'Privacy Policy',
    'versions': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'version-2',
        'version': 2,
        'title': 'Previous policy',
        'status': 'superseded',
        'change_summary': null,
        'published_at': '2026-08-01T08:00:00Z',
      },
    ],
  },
};

const _statusResponse = <String, dynamic>{
  'data': _statusData,
};

const _directStatusResponse = _statusData;

const _statusData = <String, dynamic>{
  'policies': <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'terms_of_service',
      'label': 'Terms of Service',
      'required': true,
      'accepted': false,
      'accepted_at': null,
      'current_version': 3,
      'accepted_version': null,
    },
    <String, dynamic>{
      'type': 'privacy_policy',
      'label': 'Privacy Policy',
      'required': true,
      'accepted': true,
      'accepted_at': '2026-08-02T08:00:00Z',
      'current_version': 2,
      'accepted_version': 2,
    },
  ],
  'all_required_accepted': false,
};

const _acceptanceResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'type': 'terms_of_service',
    'label': 'Terms of Service',
    'version': _versionJson,
    'accepted_at': '2026-09-10T08:05:00Z',
  },
};
