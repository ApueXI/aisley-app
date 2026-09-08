import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  test('parses the redacted Courier identity and affiliation separately', () {
    final courier = CourierIdentity.fromJson(const <String, dynamic>{
      'id': 'courier-1',
      'email': 'courier@example.com',
      'role': 'courier',
      'status': 'active',
      'profile': <String, dynamic>{
        'first_name': 'Maya',
        'last_name': 'Santos',
        'age': 28,
      },
      'logistics': <String, dynamic>{
        'status': 'approved',
        'organization': <String, dynamic>{'business_name': 'Aisley Express'},
        'hub': <String, dynamic>{'name': 'Makati Hub'},
      },
    });

    expect(courier.status, CourierAccountStatus.active);
    expect(courier.logistics?.status, CourierAffiliationStatus.approved);
    expect(courier.displayName, 'Maya Santos');
    expect(courier.organizationName, 'Aisley Express');
    expect(courier.hubName, 'Makati Hub');
  });

  test('fails safely on an unknown account status', () {
    expect(
      () => CourierIdentity.fromJson(const <String, dynamic>{
        'id': 'courier-1',
        'email': 'courier@example.com',
        'role': 'courier',
        'status': 'new_server_status',
      }),
      throwsA(isA<ApiContractException>()),
    );
  });

  test(
    'parses the unavailable dashboard scaffold without fabricating work',
    () {
      final dashboard = DashboardSnapshot.fromJson(_dashboardJson);

      expect(dashboard.freshness.state, DashboardFreshnessState.scaffold);
      expect(
        dashboard.section('available_tasks').state,
        DashboardSectionState.unavailable,
      );
      expect(dashboard.section('available_tasks').items, isEmpty);
    },
  );
}

const _dashboardJson = <String, dynamic>{
  'data': <dynamic>[],
  'meta': <String, dynamic>{'generated_at': 'now'},
  'sections': <String, dynamic>{
    'available_tasks': <String, dynamic>{
      'state': 'unavailable',
      'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    },
  },
  'freshness': <String, dynamic>{
    'state': 'scaffold',
    'reason': 'OPERATIONAL_SCHEMA_DEFERRED',
    'generated_at': 'now',
  },
};
