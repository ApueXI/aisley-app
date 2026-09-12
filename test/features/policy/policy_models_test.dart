import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';

void main() {
  test(
    'maps UTC timestamps and preserves unknown status types as unsupported',
    () {
      final status = PolicyConsentStatus.fromJson(const <String, dynamic>{
        'policies': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'internal_rules',
            'label': 'Internal Rules',
            'required': false,
            'accepted': false,
            'accepted_at': null,
            'current_version': null,
            'accepted_version': null,
          },
        ],
        'all_required_accepted': true,
      });

      expect(status.policies.single.isSupported, isFalse);
      expect(status.policies.single.rawType, 'internal_rules');
    },
  );

  test('normalizes deployed policy version projections', () {
    final status = PolicyConsentStatus.fromJson(const <String, dynamic>{
      'policies': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'terms_of_service',
          'label': 'Terms of Service',
          'required': true,
          'accepted': true,
          'accepted_at': null,
          'current_version': '3',
          'accepted_version': <String, dynamic>{'version': 3},
        },
      ],
      'all_required_accepted': true,
    });

    expect(status.policies.single.currentVersion, 3);
    expect(status.policies.single.acceptedVersion, 3);
  });

  test('rejects malformed version timestamps and missing policy envelopes', () {
    expect(
      () => PolicyVersion.fromJson(const <String, dynamic>{
        'id': 'version-1',
        'version': 1,
        'title': 'Terms',
        'content': 'Content',
        'status': 'published',
        'change_summary': null,
        'requires_reconsent': false,
        'published_at': 'not-a-timestamp',
      }),
      throwsA(isA<ApiContractException>()),
    );
    expect(
      () => PolicyConsentStatus.fromJson(const <String, dynamic>{}),
      throwsA(isA<ApiContractException>()),
    );
  });

  test('does not expose draft versions in published history', () {
    final history = PolicyHistory.fromJson(const <String, dynamic>{
      'type': 'terms_of_service',
      'label': 'Terms of Service',
      'versions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'draft-1',
          'version': 4,
          'title': 'Draft',
          'status': 'draft',
          'change_summary': null,
          'published_at': null,
        },
      ],
    });

    expect(history.versions, isEmpty);
  });
}
