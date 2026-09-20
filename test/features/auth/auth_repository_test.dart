import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';

void main() {
  test('preserves nested registration validation field paths', () {
    final error = ApiException.fromResponse(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': 'The given data was invalid.',
          'errors': <String, Object?>{
            'address': <String, Object?>{
              'postal_code': <String>['Enter a valid postal code.'],
            },
            'email': <String>['This email is already registered.'],
          },
        }),
        422,
      ),
    );

    expect(
      error.fieldErrors['address.postal_code']!.single,
      contains('valid postal code'),
    );
    expect(error.fieldErrors['email']!.single, contains('already registered'));
  });

  test('loads only public active Logistics organization options', () async {
    late http.Request request;
    final storage = FakeTokenStorage();
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <Map<String, String>>[
              <String, String>{
                'id': 'logistics-1',
                'business_name': 'Aisley Express',
              },
            ],
          }),
          200,
        );
      }),
    );
    final repository = ApiAuthRepository(client: client, tokenStorage: storage);

    final options = await repository.fetchLogisticsOptions(search: 'Express');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/auth/logistics-options');
    expect(request.url.queryParameters['search'], 'Express');
    expect(options.single.id, 'logistics-1');
    expect(options.single.businessName, 'Aisley Express');
  });

  test('registration uses exact multipart fields and does not send authority fields', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'aisley_registration_test_',
    );
    addTearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });
    final governmentId = File('${temporaryDirectory.path}/id.png');
    final vehicleRegistration = File('${temporaryDirectory.path}/or-cr.png');
    await governmentId.writeAsBytes(<int>[0x89, 0x50, 0x4e, 0x47]);
    await vehicleRegistration.writeAsBytes(<int>[0x89, 0x50, 0x4e, 0x47]);

    late http.Request request;
    final storage = FakeTokenStorage();
    final client = ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: storage,
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(<String, Object?>{
            'message': 'Registration submitted for Logistics approval.',
            'courier': _pendingCourierJson,
          }),
          201,
        );
      }),
    );
    final repository = ApiAuthRepository(client: client, tokenStorage: storage);

    final result = await repository.register(
      CourierRegistrationRequest(
        firstName: 'Maya',
        lastName: 'Santos',
        middleName: 'Q',
        contactNumber: '09171234567',
        sex: 'female',
        birthDate: DateTime(1998, 4, 12),
        email: 'MAYA@example.com',
        password: 'Password123',
        passwordConfirmation: 'Password123',
        logisticsOrganizationId: 'logistics-1',
        vehicleType: 'motorcycle',
        plateNumber: 'ABC 1234',
        addressLine1: '1 Main Street',
        addressLine2: 'Unit 2',
        barangay: 'Barangay One',
        cityMunicipality: 'Makati',
        province: 'Metro Manila',
        region: 'NCR',
        postalCode: '1200',
        governmentId: RegistrationUpload(
          path: governmentId.path,
          fileName: governmentId.uri.pathSegments.last,
          bytes: Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]),
        ),
        vehicleRegistration: RegistrationUpload(
          path: vehicleRegistration.path,
          fileName: vehicleRegistration.uri.pathSegments.last,
          bytes: Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]),
        ),
      ),
    );

    final body = String.fromCharCodes(request.bodyBytes);
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/courier/auth/register');
    expect(request.headers['content-type'], startsWith('multipart/form-data;'));
    expect(body, contains('name="first_name"'));
    expect(body, contains('name="middle_name"'));
    expect(body, contains('name="address[address_line_1]"'));
    expect(body, contains('name="address[address_line_2]"'));
    expect(body, contains('name="government_id"'));
    expect(body, contains('name="vehicle_registration"'));
    expect(body, contains('name="logistics_organization_id"'));
    expect(body, isNot(contains('name="role"')));
    expect(body, isNot(contains('name="hub_id"')));
    expect(body, isNot(contains('name="status"')));
    expect(result.courier.status, CourierAccountStatus.pending);
    expect(storage.token, isNull);
  });

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

const _pendingCourierJson = <String, dynamic>{
  'id': 'courier-pending-1',
  'email': 'maya@example.com',
  'role': 'courier',
  'status': 'pending',
  'profile': <String, dynamic>{'first_name': 'Maya', 'last_name': 'Santos'},
  'logistics': <String, dynamic>{'status': 'pending'},
};
