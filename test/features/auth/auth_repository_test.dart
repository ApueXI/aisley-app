import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';

void main() {
  test('login sends only the documented fields and stores the token', () async {
    late http.Request request;
    final storage = FakeTokenStorage();
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(<String, Object?>{
            'token': 'plain-token-once',
            'courier': _courierJson,
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiAuthRepository(client: client, tokenStorage: storage);

    final courier = await repository.login(
      email: 'COURIER@example.com',
      password: 'not-logged',
      deviceName: 'Courier Flutter',
    );

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/courier/auth/login');
    expect(
      body.keys,
      containsAll(<String>['email', 'password', 'device_name']),
    );
    expect(body.keys, isNot(contains('role')));
    expect(body.keys, isNot(contains('abilities')));
    expect(body['email'], 'courier@example.com');
    expect(storage.token, 'plain-token-once');
    expect(courier.role, 'courier');
  });

  test('authenticated requests attach the stored bearer token', () async {
    final storage = FakeTokenStorage()..token = 'stored-token';
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer stored-token');
        return http.Response(
          jsonEncode(<String, Object?>{'courier': _courierJson}),
          200,
        );
      }),
    );

    final repository = ApiAuthRepository(client: client, tokenStorage: storage);

    await repository.currentCourier();
  });
}

class FakeTokenStorage implements TokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

const _courierJson = <String, dynamic>{
  'id': 'courier-1',
  'email': 'courier@example.com',
  'role': 'courier',
  'status': 'active',
  'profile': <String, dynamic>{'first_name': 'Maya', 'last_name': 'Santos'},
  'logistics': <String, dynamic>{
    'status': 'approved',
    'organization': 'Aisley Express',
    'hub': 'Makati Hub',
  },
};
