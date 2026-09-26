import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/batch/data/final_mile_batch_repository.dart';
import 'package:aisley_app/features/batch/domain/final_mile_batch_models.dart';

void main() {
  test('uses the schedule-scoped batch list and detail routes', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(
          request.url.path.endsWith('/final-mile-batches')
              ? <String, Object?>{
                  'data': <Object?>[_offeredBatch],
                }
              : <String, Object?>{'data': _offeredBatch},
        ),
        200,
      );
    });

    final batches = await repository.fetchBatches();
    final detail = await repository.fetchBatch('schedule-1');

    expect(requests[0].method, 'GET');
    expect(requests[0].url.path, '/api/v1/courier/final-mile-batches');
    expect(
      requests[1].url.path,
      '/api/v1/courier/final-mile-batches/schedule-1',
    );
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer batch-token',
      ),
      isTrue,
    );
    expect(batches.single.parcelCount, 2);
    expect(detail.tasks.first.parcel.price, '1250.00');
    expect(detail.tasks.first.parcel.currency, 'PHP');
    expect(detail.tasks.first.parcel.itemCount, 3);
    expect(detail.tasks.last.destination.cityMunicipality, 'Pasig City');
  });

  test(
    'accepts one whole batch with empty JSON and no idempotency key',
    () async {
      late http.Request recorded;
      final repository = _repository((request) async {
        recorded = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{..._offeredBatch, 'status': 'accepted'},
          }),
          200,
        );
      });

      final batch = await repository.acceptBatch('schedule-1');

      expect(recorded.method, 'POST');
      expect(
        recorded.url.path,
        '/api/v1/courier/final-mile-batches/schedule-1/accept',
      );
      expect(jsonDecode(recorded.body), <String, Object?>{});
      expect(recorded.headers.containsKey('idempotency-key'), isFalse);
      expect(batch.status, FinalMileBatchStatus.accepted);
    },
  );
}

ApiFinalMileBatchRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ApiFinalMileBatchRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'batch-token',
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

const _offeredBatch = <String, Object?>{
  'id': 'schedule-1',
  'reference': 'DSP-100',
  'scheduled_for': '2026-09-27T01:30:00Z',
  'parcel_count': 2,
  'status': 'offered',
  'tasks': <Object?>[
    <String, Object?>{
      'id': 'task-1',
      'leg': 'final_mile',
      'status': 'delivery_assigned',
      'order': <String, Object?>{'reference': 'ORD-100'},
      'parcel': <String, Object?>{
        'id': 'parcel-1',
        'reference': 'PAR-100',
        'item_count': 3,
        'price': '1250.00',
        'currency': 'PHP',
      },
      'destination_area': <String, Object?>{
        'city_municipality': 'Makati City',
        'province': 'Metro Manila',
      },
    },
    <String, Object?>{
      'id': 'task-2',
      'leg': 'final_mile',
      'status': 'delivery_assigned',
      'order': <String, Object?>{'reference': 'ORD-101'},
      'parcel': <String, Object?>{
        'id': 'parcel-2',
        'reference': 'PAR-101',
        'item_count': 1,
        'price': 499.5,
        'currency': 'PHP',
      },
      'destination_area': <String, Object?>{
        'city_municipality': 'Pasig City',
        'province': 'Metro Manila',
      },
    },
  ],
};
