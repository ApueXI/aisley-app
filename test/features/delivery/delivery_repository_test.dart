import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';

void main() {
  test('reads the exact final-mile task and current revision', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'id': 'delivery-task-1',
            'leg': 'final_mile',
            'status': 'out_for_delivery',
            'revision': 9,
            'order': <String, String>{'reference': 'ORD-100'},
          },
        }),
        200,
      );
    });

    final task = await repository.fetchFinalMileTask('delivery-task-1');

    expect(
      request.url.path,
      '/api/v1/courier/final-mile-tasks/delivery-task-1',
    );
    expect(request.headers['authorization'], 'Bearer delivery-token');
    expect(task.id, 'delivery-task-1');
    expect(task.revision, 9);
    expect(task.order?.reference, 'ORD-100');
  });

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
      expect(context.codCollection?.displayAmount, 'PHP 115.00');
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
      idempotencyKey: '66666666-6666-4666-8666-666666666666',
    );

    expect(request.method, 'POST');
    expect(
      request.url.path,
      '/api/v1/courier/final-mile-tasks/delivery-task-1/status',
    );
    expect(request.headers['authorization'], 'Bearer delivery-token');
    expect(
      request.headers['idempotency-key'],
      '66666666-6666-4666-8666-666666666666',
    );
    expect(jsonDecode(request.body), <String, dynamic>{
      'target_state': 'in_transit',
      'expected_revision': 4,
    });
    expect(update.status, 'in_transit');
    expect(update.revision, 5);
  });

  test(
    'submits multipart photo proof with revision and idempotency header',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_proofResponse), 202);
      });

      final proof = await repository.submitProof(
        taskId: 'delivery-task-1',
        photo: _photo(),
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
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="expected_revision"'));
      expect(body, contains('name="photo"; filename="proof.jpg"'));
      expect(body, contains('6'));
      expect(body, isNot(contains('identifier_type')));
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
        codCollected: true,
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
        'cod_collected': true,
      });
      expect(completion.isDelivered, isFalse);
      expect(completion.completionStatus, 'awaiting_validation');
    },
  );

  test(
    'accepts a direct completion DTO when the data envelope is omitted',
    () async {
      final repository = _repository((incoming) async {
        return http.Response(jsonEncode(_directCompletionResponse), 202);
      });

      final completion = await repository.submitCompletion(
        taskId: 'delivery-task-1',
        expectedRevision: 7,
        evidenceId: 'proof-1',
        idempotencyKey: '44444444-4444-4444-8444-444444444444',
        codCollected: true,
      );

      expect(completion.taskId, 'delivery-task-1');
      expect(completion.intentId, 'intent-1');
      expect(completion.completionStatus, 'awaiting_validation');
      expect(completion.isDelivered, isFalse);
    },
  );

  test(
    'reads the completion projection after a 202 acknowledgment without a DTO',
    () async {
      final requests = <http.Request>[];
      final repository = _repository((incoming) async {
        requests.add(incoming);
        if (incoming.method == 'POST') {
          return http.Response('', 202);
        }
        return http.Response(jsonEncode(_completionResponse), 200);
      });

      final completion = await repository.submitCompletion(
        taskId: 'delivery-task-1',
        expectedRevision: 7,
        evidenceId: 'proof-1',
        idempotencyKey: '55555555-5555-4555-8555-555555555555',
        codCollected: true,
      );

      expect(requests.map((request) => request.method), <String>[
        'POST',
        'GET',
      ]);
      expect(
        requests.last.url.path,
        '/api/v1/courier/tasks/delivery-task-1/completion',
      );
      expect(completion.intentId, 'intent-1');
      expect(completion.completionStatus, 'awaiting_validation');
      expect(completion.isDelivered, isFalse);
    },
  );

  test('accepts a null completion status before an intent exists', () async {
    final repository = _repository((incoming) async {
      return http.Response(jsonEncode(_initialCompletionResponse), 200);
    });

    final completion = await repository.fetchCompletion('delivery-task-1');

    expect(completion.intentId, isNull);
    expect(completion.completionStatus, isNull);
    expect(completion.taskStatus, 'out_for_delivery');
    expect(completion.isAwaitingValidation, isFalse);
    expect(completion.isDelivered, isFalse);
  });

  test(
    'missing COD total never falls back to parcel merchandise price',
    () async {
      final response = <String, dynamic>{
        'data': <String, dynamic>{
          'task_id': 'delivery-task-1',
          'status': 'out_for_delivery',
          'revision': 7,
          'order': <String, dynamic>{
            'payment_method': 'cod',
            'payment_status': 'pending',
            'currency': 'PHP',
          },
          'parcel': <String, dynamic>{'price': '100.00', 'currency': 'PHP'},
        },
      };
      final repository = _repository(
        (_) async => http.Response(jsonEncode(response), 200),
      );

      final context = await repository.fetchDeliveryContext('delivery-task-1');

      expect(context.payableTotal, isNull);
      expect(context.codCollection, isNull);
    },
  );

  test('non-COD payload omits the collection declaration', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_completionResponse), 202);
    });

    await repository.submitCompletion(
      taskId: 'delivery-task-1',
      expectedRevision: 7,
      evidenceId: 'proof-1',
      idempotencyKey: '77777777-7777-4777-8777-777777777777',
      codCollected: false,
    );

    expect(
      (jsonDecode(request.body) as Map<String, dynamic>).containsKey(
        'cod_collected',
      ),
      isFalse,
    );
  });

  test(
    'rejects a completion projection that omits completion_status',
    () async {
      final repository = _repository((incoming) async {
        return http.Response(jsonEncode(_missingCompletionStatusResponse), 200);
      });

      expect(
        repository.fetchCompletion('delivery-task-1'),
        throwsA(
          isA<ApiContractException>().having(
            (error) => error.field,
            'field',
            'delivery.completion.completion_status',
          ),
        ),
      );
    },
  );
}

DeliveryPhotoSelection _photo() => DeliveryPhotoSelection(
  path: null,
  fileName: 'proof.jpg',
  bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
);

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
    'order': <String, dynamic>{
      'payment_method': 'cod',
      'payment_status': 'pending',
      'payable_total': '115.00',
      'currency': 'PHP',
    },
    'parcel': <String, dynamic>{'price': '100.00', 'currency': 'PHP'},
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

const _directCompletionResponse = <String, dynamic>{
  'task_id': 'delivery-task-1',
  'intent_id': 'intent-1',
  'task_status': 'out_for_delivery',
  'order_status': 'out_for_delivery',
  'evidence_status': 'awaiting_validation',
  'completion_status': 'awaiting_validation',
  'delivered_at': null,
  'revision': 8,
};

const _initialCompletionResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'intent_id': null,
    'task_status': 'out_for_delivery',
    'order_status': 'out_for_delivery',
    'evidence_status': null,
    'completion_status': null,
    'delivered_at': null,
    'revision': 7,
  },
};

const _missingCompletionStatusResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'intent_id': null,
    'task_status': 'out_for_delivery',
    'order_status': 'out_for_delivery',
    'evidence_status': null,
    'delivered_at': null,
    'revision': 7,
  },
};
