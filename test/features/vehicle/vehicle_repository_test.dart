import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/vehicle/data/vehicle_repository.dart';
import 'package:aisley_app/features/vehicle/domain/vehicle_models.dart';

void main() {
  test('reads the sole Courier vehicle projection', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_vehicleResponse), 200);
    });

    final vehicle = await repository.fetchVehicle();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/vehicle');
    expect(request.headers['authorization'], 'Bearer vehicle-token');
    expect(vehicle.id, 'vehicle-1');
    expect(vehicle.vehicleType, 'motorcycle');
    expect(vehicle.plateNumber, 'ABC-1234');
    expect(vehicle.revision, 4);
    expect(vehicle.officialReceipt?.id, 'or-1');
    expect(vehicle.certificateOfRegistration, isNull);
  });

  test(
    'patches only submitted vehicle fields with the current revision',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_vehicleResponse), 200);
      });

      await repository.updateVehicle(
        changes: const <String, Object?>{
          'plate_number': 'XYZ-9876',
          'make': null,
        },
        expectedRevision: 4,
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      );

      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/courier/vehicle');
      expect(request.headers['authorization'], 'Bearer vehicle-token');
      expect(
        request.headers['idempotency-key'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(jsonDecode(request.body), <String, dynamic>{
        'expected_revision': 4,
        'plate_number': 'XYZ-9876',
        'make': null,
      });
    },
  );

  test(
    'uploads a single OR or CR using the documented multipart shape',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'aisley_vehicle_document_test_',
      );
      addTearDown(() async {
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      });
      final filePath = '${temporaryDirectory.path}/or.png';
      await File(filePath).writeAsBytes(<int>[0x89, 0x50, 0x4e, 0x47]);
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_vehicleResponse), 200);
      });
      final file = VehicleDocumentSelection(
        path: filePath,
        fileName: 'or.png',
        bytes: Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]),
      );

      await repository.uploadDocument(
        kind: VehicleDocumentKind.officialReceipt,
        selection: file,
        expectedRevision: 4,
        idempotencyKey: '22222222-2222-4222-8222-222222222222',
      );

      final body = String.fromCharCodes(request.bodyBytes);
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/courier/vehicle/documents/official_receipt',
      );
      expect(request.headers['authorization'], 'Bearer vehicle-token');
      expect(
        request.headers['idempotency-key'],
        '22222222-2222-4222-8222-222222222222',
      );
      expect(body, contains('name="expected_revision"'));
      expect(body, contains('name="file"'));
      expect(body, contains('filename="or.png"'));
      expect(body, isNot(contains('vehicle_id')));
      expect(body, isNot(contains('courier_id')));
    },
  );

  test('reads a private current document with the bearer token', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response.bytes(
        <int>[1, 2, 3],
        200,
        headers: const <String, String>{'content-type': 'image/png'},
      );
    });

    final document = await repository.fetchDocument(
      VehicleDocumentKind.certificateOfRegistration,
    );

    expect(request.method, 'GET');
    expect(
      request.url.path,
      '/api/v1/courier/vehicle/documents/certificate_of_registration',
    );
    expect(request.headers['authorization'], 'Bearer vehicle-token');
    expect(document.contentType, 'image/png');
    expect(document.bytes, <int>[1, 2, 3]);
  });
}

ApiVehicleRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiVehicleRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'vehicle-token',
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

const _vehicleResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'id': 'vehicle-1',
    'vehicle_type': 'motorcycle',
    'plate_number': 'ABC-1234',
    'make': 'Honda',
    'model': 'Click',
    'revision': 4,
    'official_receipt': <String, dynamic>{
      'id': 'or-1',
      'url': '/api/v1/courier/vehicle/documents/official_receipt',
    },
    'certificate_of_registration': null,
  },
};
