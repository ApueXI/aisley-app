import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';
import 'package:aisley_app/features/policy/presentation/policy_controller.dart';

void main() {
  test(
    'loads status before current documents and exposes consent required',
    () async {
      final api = _FakePolicyApi();
      final controller = PolicyController(policyApi: api);

      final loaded = await controller.load();

      expect(loaded, isTrue);
      expect(api.calls, <String>[
        'status',
        'current:terms_of_service',
        'current:privacy_policy',
      ]);
      expect(controller.state, PolicyViewState.consentRequired);
      expect(
        controller.documentFor(PolicyType.termsOfService)?.version.version,
        3,
      );
      expect(
        controller.documentFor(PolicyType.privacyPolicy)?.version.version,
        2,
      );
    },
  );

  test(
    'accepts only after a fresh current-version check and refreshes status',
    () async {
      final api = _FakePolicyApi();
      final controller = PolicyController(policyApi: api);
      await controller.load();

      final accepted = await controller.accept(PolicyType.termsOfService);

      expect(accepted, isTrue);
      expect(api.acceptedVersions, <int>[3]);
      expect(controller.state, PolicyViewState.accepted);
      expect(controller.successMessage, contains('version 3'));
    },
  );

  test(
    'stale current version reloads documents and requires new confirmation',
    () async {
      final api = _FakePolicyApi()..returnNextVersion = 4;
      final controller = PolicyController(policyApi: api);
      await controller.load();

      final accepted = await controller.accept(PolicyType.termsOfService);

      expect(accepted, isFalse);
      expect(api.acceptedVersions, isEmpty);
      expect(controller.state, PolicyViewState.staleVersion);
      expect(
        controller.documentFor(PolicyType.termsOfService)?.version.version,
        4,
      );
    },
  );

  test(
    '401 invokes the auth boundary and does not keep private status',
    () async {
      var authFailureCalled = false;
      final api = _FakePolicyApi()
        ..statusError = const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'expired',
        );
      final controller = PolicyController(
        policyApi: api,
        onAuthFailure: (error) async {
          authFailureCalled = error.statusCode == 401;
        },
      );

      final loaded = await controller.load();

      expect(loaded, isFalse);
      expect(authFailureCalled, isTrue);
      expect(controller.state, PolicyViewState.unauthorized);
      expect(controller.consentStatus, isNull);
    },
  );

  test('403 maps to forbidden without offering a local bypass', () async {
    final api = _FakePolicyApi()
      ..statusError = const ApiException(
        statusCode: 403,
        code: 'POLICY_ACTOR_FORBIDDEN',
        message: 'Courier affiliation is not eligible.',
      );
    final controller = PolicyController(policyApi: api);

    await controller.load();

    expect(controller.state, PolicyViewState.forbidden);
    expect(controller.errorMessage, 'Courier affiliation is not eligible.');
  });

  test('missing policy status route explains the deployment problem', () async {
    final api = _FakePolicyApi()
      ..statusError = const ApiException(
        statusCode: 404,
        code: 'NOT_FOUND',
        message: 'not found',
      );
    final controller = PolicyController(policyApi: api);

    await controller.load();

    expect(controller.state, PolicyViewState.retryableError);
    expect(
      controller.errorMessage,
      'The policy consent endpoint is unavailable on this API. Deploy the policy routes and retry.',
    );
  });

  test('secure-storage failure explains the local recovery action', () async {
    final api = _FakePolicyApi()
      ..statusError = TokenStorageException('read', StateError('locked'));
    final controller = PolicyController(policyApi: api);

    await controller.load();

    expect(controller.state, PolicyViewState.retryableError);
    expect(
      controller.errorMessage,
      'Secure session storage is unavailable. Unlock your keyring and retry.',
    );
  });

  test('422 keeps the document open when confirmation is rejected', () async {
    final api = _FakePolicyApi()
      ..acceptError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'confirmation is required',
      );
    final controller = PolicyController(policyApi: api);
    await controller.load();

    final accepted = await controller.accept(PolicyType.termsOfService);

    expect(accepted, isFalse);
    expect(controller.state, PolicyViewState.validationError);
    expect(controller.documentFor(PolicyType.termsOfService), isNotNull);
  });

  test(
    '409 stale response reloads the current policy before reconfirmation',
    () async {
      final api = _FakePolicyApi()
        ..acceptError = const ApiException(
          statusCode: 409,
          code: 'POLICY_VERSION_STALE',
          message: 'stale',
        );
      final controller = PolicyController(policyApi: api);
      await controller.load();

      final accepted = await controller.accept(PolicyType.termsOfService);

      expect(accepted, isFalse);
      expect(controller.state, PolicyViewState.staleVersion);
      expect(api.statusCallCount, greaterThanOrEqualTo(3));
    },
  );

  test(
    '429 honors retry delay and disables retry while rate limited',
    () async {
      final api = _FakePolicyApi()
        ..statusError = const ApiException(
          statusCode: 429,
          code: 'THROTTLED',
          message: 'slow down',
          retryAfter: Duration(seconds: 30),
        );
      final controller = PolicyController(policyApi: api);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state, PolicyViewState.rateLimited);
      expect(controller.canRetryRateLimit, isFalse);
      expect(controller.retryAfter, const Duration(seconds: 30));
    },
  );

  test(
    'unknown acceptance result is reconciled without replaying the mutation',
    () async {
      final api = _FakePolicyApi()
        ..acceptError = const ApiException.network(
          'timed out',
          networkFailure: ApiNetworkFailure.timeout,
        )
        ..markAcceptedOnStatusRefresh = true;
      final controller = PolicyController(policyApi: api);
      await controller.load();

      final accepted = await controller.accept(PolicyType.termsOfService);

      expect(accepted, isTrue);
      expect(api.acceptedVersions, <int>[3]);
      expect(controller.state, PolicyViewState.accepted);
    },
  );
}

class _FakePolicyApi implements PolicyApi {
  final List<String> calls = <String>[];
  final List<int> acceptedVersions = <int>[];
  Object? statusError;
  Object? acceptError;
  int? returnNextVersion;
  bool markAcceptedOnStatusRefresh = false;
  int _statusCallCount = 0;

  int get statusCallCount => _statusCallCount;

  @override
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    calls.add('current:${type.apiValue}');
    final version = type == PolicyType.termsOfService
        ? (returnNextVersion ?? 3)
        : 2;
    return _document(type, version);
  }

  @override
  Future<PolicyHistory> fetchHistory(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    calls.add('history:${type.apiValue}');
    return PolicyHistory(
      type: type,
      label: type.fallbackLabel,
      versions: const <PolicyHistoryEntry>[],
    );
  }

  @override
  Future<PolicyDocument> fetchHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  }) async {
    calls.add('history-version:${type.apiValue}:$version');
    return _document(type, version);
  }

  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async {
    calls.add('status');
    final error = statusError;
    if (error != null) {
      throw error;
    }
    _statusCallCount += 1;
    final accepted = markAcceptedOnStatusRefresh && _statusCallCount > 1;
    return PolicyConsentStatus(
      policies: <PolicyConsentItem>[
        PolicyConsentItem(
          rawType: 'terms_of_service',
          label: 'Terms of Service',
          required: true,
          accepted: accepted,
          acceptedAt: accepted ? DateTime.utc(2026, 9, 10) : null,
          currentVersion: 3,
          acceptedVersion: accepted ? 3 : null,
        ),
        const PolicyConsentItem(
          rawType: 'privacy_policy',
          label: 'Privacy Policy',
          required: true,
          accepted: true,
          acceptedAt: null,
          currentVersion: 2,
          acceptedVersion: 2,
        ),
      ],
      allRequiredAccepted: accepted,
    );
  }

  @override
  Future<PolicyAcceptance> accept({
    required PolicyType type,
    required int version,
  }) async {
    final error = acceptError;
    if (error != null) {
      acceptedVersions.add(version);
      throw error;
    }
    acceptedVersions.add(version);
    return PolicyAcceptance(
      type: type,
      label: type.fallbackLabel,
      version: _document(type, version).version,
      acceptedAt: DateTime.utc(2026, 9, 10),
    );
  }

  @override
  void clearPublicCache() {}
}

PolicyDocument _document(PolicyType type, int version) {
  return PolicyDocument(
    type: type,
    label: type.fallbackLabel,
    version: PolicyVersion(
      id: '${type.apiValue}-$version',
      version: version,
      title: '${type.fallbackLabel} version $version',
      content: 'Policy content for ${type.fallbackLabel} version $version.',
      status: 'published',
      changeSummary: null,
      requiresReconsent: true,
      publishedAt: DateTime.utc(2026, 9, 10),
    ),
  );
}
