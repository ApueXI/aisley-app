import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';

void main() {
  test(
    'reads final-mile delivery context with nullable advisory fields',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_deliveryContextResponse), 200);
      });

      final context = await repository.fetchDeliveryContext('delivery-task-1');

      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/v1/courier/tasks/delivery-task-1/delivery',
      );
      expect(request.headers['authorization'], 'Bearer delivery-token');
      expect(context.taskId, 'delivery-task-1');
      expect(context.status, 'delivery_accepted');
      expect(context.destination?.cityMunicipality, 'Pasig');
      expect(context.distanceKm, isNull);
      expect(context.routeStatus, 'unavailable');
    },
  );

  test('advances only the documented movement target and revision', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_statusResponse), 200);
    });

    final update = await repository.advanceStatus(
      taskId: 'delivery-task-1',
      status: 'in_transit',
      expectedRevision: 4,
    );

    expect(request.method, 'POST');
    expect(
      request.url.path,
      '/api/v1/courier/final-mile-tasks/delivery-task-1/status',
    );
    expect(request.headers['authorization'], 'Bearer delivery-token');
    expect(jsonDecode(request.body), <String, dynamic>{
      'status': 'in_transit',
      'expected_revision': 4,
    });
    expect(update.status, 'in_transit');
    expect(update.revision, 5);
  });

  test(
    'submits QR proof with the exact P0 body and idempotency header',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_proofResponse), 202);
      });

      final proof = await repository.submitProof(
        taskId: 'delivery-task-1',
        identifierType: 'qr',
        identifier: ' RECIPIENT-QR ',
        expectedRevision: 6,
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      );

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/courier/tasks/delivery-task-1/proof-of-delivery',
      );
      expect(
        request.headers['idempotency-key'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(jsonDecode(request.body), <String, dynamic>{
        'identifier_type': 'qr',
        'identifier': 'RECIPIENT-QR',
        'expected_revision': 6,
      });
      expect(proof.proofId, 'proof-1');
      expect(proof.completionEligible, isFalse);
    },
  );

  test(
    'submits completion intent without claiming delivery from 202',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_completionResponse), 202);
      });

      final completion = await repository.submitCompletion(
        taskId: 'delivery-task-1',
        expectedRevision: 7,
        evidenceId: 'proof-1',
        idempotencyKey: '22222222-2222-4222-8222-222222222222',
      );

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/courier/tasks/delivery-task-1/completion',
      );
      expect(jsonDecode(request.body), <String, dynamic>{
        'expected_revision': 7,
        'evidence_id': 'proof-1',
        'confirmed': true,
      });
      expect(completion.isDelivered, isFalse);
      expect(completion.completionStatus, 'awaiting_validation');
    },
  );
}

ApiDeliveryRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiDeliveryRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'delivery-token',
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

const _deliveryContextResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'status': 'delivery_accepted',
    'revision': 4,
    'hub': <String, dynamic>{'hub_name': 'Makati Hub'},
    'destination': <String, dynamic>{
      'city_municipality': 'Pasig',
      'province': 'Metro Manila',
    },
    'recipient_name': 'Ana Santos',
    'recipient_phone': '+63 900 000 0000',
    'route_status': 'unavailable',
    'distance_km': null,
    'estimated_duration_minutes': null,
  },
};

const _statusResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'status': 'in_transit',
    'revision': 5,
  },
};

const _proofResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'proof_id': 'proof-1',
    'evidence_status': 'awaiting_validation',
    'custody_state': 'out_for_delivery',
    'completion_eligible': false,
    'submitted_at': '2026-09-13T04:00:00Z',
  },
};

const _completionResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'intent_id': 'intent-1',
    'task_status': 'out_for_delivery',
    'order_status': 'out_for_delivery',
    'evidence_status': 'awaiting_validation',
    'completion_status': 'awaiting_validation',
    'delivered_at': null,
    'revision': 8,
  },
};
