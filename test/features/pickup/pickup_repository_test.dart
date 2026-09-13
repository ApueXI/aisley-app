import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

void main() {
  test('lists first-mile tasks with the documented private query', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_firstMileListResponse), 200);
    });

    final page = await repository.fetchFirstMileTasks(
      pickupScheduleId: 'schedule-1',
    );

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/courier/first-mile-tasks');
    expect(request.url.queryParameters, <String, String>{
      'pickup_schedule_id': 'schedule-1',
      'per_page': '50',
    });
    expect(request.headers['authorization'], 'Bearer pickup-token');
    expect(page.tasks.single.id, 'task-1');
    expect(page.tasks.single.leg, PickupTaskLeg.firstMile);
    expect(page.tasks.single.order?.reference, 'ORD-100');
    expect(page.tasks.single.pickup?.cityMunicipality, 'Makati');
    expect(page.tasks.single.schedule?.startsAt, isNotNull);
  });

  test('accepts a first-mile task without client ownership fields', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            ..._firstMileListResponse['data'] is List
                ? (_firstMileListResponse['data'] as List).first
                      as Map<String, dynamic>
                : <String, dynamic>{},
            'status': 'accepted',
          },
        }),
        200,
      );
    });

    final task = await repository.acceptFirstMileTask('task-1');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/courier/first-mile-tasks/task-1/accept');
    expect(request.headers['authorization'], 'Bearer pickup-token');
    expect(jsonDecode(request.body), <String, dynamic>{});
    expect(task.rawStatus, 'accepted');
  });

  test('resolves a QR candidate through the read-only waybill route', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode(const <String, dynamic>{
          'data': <String, dynamic>{
            'task_id': 'task-1',
            'order': <String, dynamic>{'id': 'order-1', 'reference': 'ORD-100'},
            'waybill': <String, dynamic>{'reference': 'WB-100'},
          },
        }),
        200,
      );
    });

    final resolution = await repository.resolveWaybill('AISLEY:WB:1:WB-100');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/courier/waybills/resolve');
    expect(request.headers['authorization'], 'Bearer pickup-token');
    expect(jsonDecode(request.body), <String, dynamic>{
      'payload': 'AISLEY:WB:1:WB-100',
    });
    expect(resolution.taskId, 'task-1');
    expect(resolution.orderReference, 'ORD-100');
  });

  test(
    'confirms first-mile pickup with exact body and idempotency header',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_firstMilePickupResponse), 200);
      });

      final result = await repository.confirmFirstMilePickup(
        taskId: 'task-1',
        identifierType: 'qr',
        identifier: ' AISLEY:WB:1:WB-100 ',
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
      );

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/v1/courier/first-mile-tasks/task-1/pickup',
      );
      expect(request.headers['authorization'], 'Bearer pickup-token');
      expect(
        request.headers['idempotency-key'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(jsonDecode(request.body), <String, dynamic>{
        'identifier_type': 'qr',
        'identifier': 'AISLEY:WB:1:WB-100',
      });
      expect(result.taskStatus, 'picked_up_from_seller');
      expect(result.orderStatus, 'picked_up');
      expect(result.pickedUpAt, isNotNull);
    },
  );

  test('reads final-mile tasks and submits pending hub evidence', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      if (incoming.url.path.endsWith('/pickup')) {
        return http.Response(jsonEncode(_finalMilePickupResponse), 202);
      }
      return http.Response(jsonEncode(_finalMileListResponse), 200);
    });

    final tasks = await repository.fetchFinalMileTasks();
    expect(request.url.path, '/api/v1/courier/final-mile-tasks');
    expect(tasks.single.leg, PickupTaskLeg.finalMile);
    expect(tasks.single.revision, 4);

    final result = await repository.submitFinalMilePickup(
      taskId: 'delivery-task-1',
      identifierType: 'order_id',
      identifier: 'ORD-100',
      expectedRevision: 4,
      idempotencyKey: '22222222-2222-4222-8222-222222222222',
    );

    expect(request.method, 'POST');
    expect(
      request.url.path,
      '/api/v1/courier/final-mile-tasks/delivery-task-1/pickup',
    );
    expect(request.headers['authorization'], 'Bearer pickup-token');
    expect(
      request.headers['idempotency-key'],
      '22222222-2222-4222-8222-222222222222',
    );
    expect(jsonDecode(request.body), <String, dynamic>{
      'identifier_type': 'order_id',
      'identifier': 'ORD-100',
      'expected_revision': 4,
    });
    expect(result.evidenceStatus, 'awaiting_validation');
    expect(result.custodyState, 'delivery_accepted');
  });

  test('rejects a final-mile offer with the documented reason and key', () async {
    late http.Request request;
    final repository = _repository((incoming) async {
      request = incoming;
      return http.Response(jsonEncode(_finalMileRejectionResponse), 200);
    });

    final result = await repository.rejectFinalMileTask(
      taskId: 'delivery-task-1',
      reason: ' Unable to take this task today ',
      idempotencyKey: '33333333-3333-4333-8333-333333333333',
    );

    expect(request.method, 'POST');
    expect(
      request.url.path,
      '/api/v1/courier/final-mile-tasks/delivery-task-1/reject',
    );
    expect(request.headers['authorization'], 'Bearer pickup-token');
    expect(
      request.headers['idempotency-key'],
      '33333333-3333-4333-8333-333333333333',
    );
    expect(jsonDecode(request.body), <String, dynamic>{
      'reason': 'Unable to take this task today',
    });
    expect(result.taskId, 'delivery-task-1');
    expect(result.status, 'rejected');
    expect(result.rejectionReason, 'Unable to take this task today');
  });

  test(
    'loads the schedule-scoped route manifest without map credentials',
    () async {
      late http.Request request;
      final repository = _repository((incoming) async {
        request = incoming;
        return http.Response(jsonEncode(_manifestResponse), 200);
      });

      final manifest = await repository.fetchRouteManifest('schedule-1');

      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/v1/courier/pickup-schedules/schedule-1/route-manifest',
      );
      expect(request.headers['authorization'], 'Bearer pickup-token');
      expect(manifest.status, RouteManifestStatus.ready);
      expect(manifest.stops.map((stop) => stop.kind), <String>[
        'hub',
        'pickup',
      ]);
      expect(manifest.geoJson?['type'], 'FeatureCollection');
    },
  );
}

ApiPickupRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiPickupRepository(
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example.test'),
      tokenStorage: _FakeTokenStorage()..token = 'pickup-token',
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

const _firstMileListResponse = <String, dynamic>{
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'task-1',
      'leg': 'first_mile',
      'status': 'assigned',
      'pickup_schedule_id': 'schedule-1',
      'order': <String, dynamic>{'id': 'order-1', 'reference': 'ORD-100'},
      'waybill': <String, dynamic>{'reference': 'WB-100'},
      'pickup': <String, dynamic>{
        'shop_name': 'Santos Shop',
        'address_line_1': '10 Main Street',
        'barangay': 'Poblacion',
        'city_municipality': 'Makati',
        'province': 'Metro Manila',
        'region': 'NCR',
        'postal_code': '1200',
      },
      'destination_area': <String, dynamic>{
        'city_municipality': 'Pasig',
        'province': 'Metro Manila',
      },
      'schedule': <String, dynamic>{
        'id': 'schedule-1',
        'reference': 'SCH-100',
        'starts_at': '2026-09-12T01:00:00Z',
        'ends_at': '2026-09-12T03:00:00Z',
        'timezone': 'UTC',
      },
    },
  ],
  'meta': <String, dynamic>{
    'current_page': 1,
    'last_page': 1,
    'per_page': 50,
    'total': 1,
  },
};

const _firstMilePickupResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'task-1',
    'order': <String, dynamic>{'id': 'order-1', 'reference': 'ORD-100'},
    'waybill': <String, dynamic>{'reference': 'WB-100'},
    'task_status': 'picked_up_from_seller',
    'order_status': 'picked_up',
    'picked_up_at': '2026-09-12T03:05:00Z',
    'next_step': 'Transfer the parcel to the Logistics hub.',
    'idempotent': false,
  },
};

const _finalMileListResponse = <String, dynamic>{
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'delivery-task-1',
      'leg': 'final_mile',
      'status': 'delivery_accepted',
      'revision': 4,
      'order': <String, dynamic>{'reference': 'ORD-100'},
      'waybill': <String, dynamic>{'reference': 'WB-100'},
      'pickup': <String, dynamic>{'hub_name': 'Makati Hub'},
      'destination_area': <String, dynamic>{
        'city_municipality': 'Pasig',
        'province': 'Metro Manila',
      },
    },
  ],
};

const _finalMilePickupResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'evidence_id': 'evidence-1',
    'evidence_status': 'awaiting_validation',
    'custody_state': 'delivery_accepted',
    'submitted_at': '2026-09-12T03:10:00Z',
  },
};

const _finalMileRejectionResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'task_id': 'delivery-task-1',
    'status': 'rejected',
    'offer': <String, dynamic>{
      'responded_at': '2026-09-12T03:12:00Z',
      'rejection_reason': 'Unable to take this task today',
    },
  },
};

const _manifestResponse = <String, dynamic>{
  'data': <String, dynamic>{
    'status': 'ready',
    'schedule_id': 'schedule-1',
    'revision': 2,
    'coordinate_source': 'exact',
    'summary': <String, dynamic>{'stop_count': 1},
    'stops': <Map<String, dynamic>>[
      <String, dynamic>{
        'sequence': 0,
        'kind': 'hub',
        'address_summary': 'Makati Hub',
        'reachable': true,
      },
      <String, dynamic>{
        'sequence': 1,
        'kind': 'pickup',
        'task_ids': <String>['task-1'],
        'order_references': <String>['ORD-100'],
        'address_summary': 'Poblacion, Makati',
        'reachable': true,
      },
    ],
    'geojson': <String, dynamic>{'type': 'FeatureCollection', 'features': []},
    'calculated_at': '2026-09-12T00:00:00Z',
    'reason': null,
  },
};
