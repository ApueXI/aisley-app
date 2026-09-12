import 'dart:collection';
import 'dart:convert';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../domain/policy_models.dart';

abstract interface class PolicyApi {
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  });

  Future<PolicyHistory> fetchHistory(
    PolicyType type, {
    bool forceRefresh = false,
  });

  Future<PolicyDocument> fetchHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  });

  Future<PolicyConsentStatus> fetchConsentStatus();

  Future<PolicyAcceptance> accept({
    required PolicyType type,
    required int version,
  });

  void clearPublicCache();
}

class ApiPolicyRepository implements PolicyApi {
  ApiPolicyRepository({required this._client});

  static const _currentCacheTtl = Duration(minutes: 5);
  static const _historyCacheTtl = Duration(minutes: 1);
  static const _maxCachedEntries = 8;

  final ApiClient _client;
  final Map<PolicyType, _Cached<PolicyDocument>> _currentCache = {};
  final Map<PolicyType, _Cached<PolicyHistory>> _historyCache = {};
  final LinkedHashMap<String, _Cached<PolicyDocument>> _versionCache =
      LinkedHashMap<String, _Cached<PolicyDocument>>();

  @override
  Future<PolicyDocument> fetchCurrent(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    final cached = _currentCache[type];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.value;
    }

    final response = await _client.get('/platform/policies/${type.apiValue}');
    final document = PolicyDocument.fromJson(_dataMap(response.body, 'policy'));
    if (document.type != type || document.version.status != 'published') {
      throw const ApiContractException('policy.current.version');
    }
    _currentCache[type] = _Cached(document, _currentCacheTtl);
    return document;
  }

  @override
  Future<PolicyHistory> fetchHistory(
    PolicyType type, {
    bool forceRefresh = false,
  }) async {
    final cached = _historyCache[type];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.value;
    }

    final response = await _client.get(
      '/platform/policies/${type.apiValue}/history',
    );
    final history = PolicyHistory.fromJson(
      _dataMap(response.body, 'policy.history'),
    );
    _historyCache[type] = _Cached(history, _historyCacheTtl);
    return history;
  }

  @override
  Future<PolicyDocument> fetchHistoryVersion(
    PolicyType type,
    int version, {
    bool forceRefresh = false,
  }) async {
    if (version < 1) {
      throw const ApiContractException('policy.version.path');
    }
    final key = '${type.apiValue}:$version';
    final cached = _versionCache[key];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.value;
    }

    final response = await _client.get(
      '/platform/policies/${type.apiValue}/history/$version',
    );
    final document = PolicyDocument.fromJson(_dataMap(response.body, 'policy'));
    if (document.type != type ||
        (document.version.status != 'published' &&
            document.version.status != 'superseded')) {
      throw const ApiContractException('policy.history.version');
    }
    if (document.version.version != version) {
      throw const ApiContractException('policy.history.version');
    }
    _cacheVersion(key, document);
    return document;
  }

  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async {
    final response = await _client.get(
      '/policy-consent/status',
      authenticated: true,
    );
    return PolicyConsentStatus.fromJson(
      _dataMap(response.body, 'policy.consent'),
    );
  }

  @override
  Future<PolicyAcceptance> accept({
    required PolicyType type,
    required int version,
  }) async {
    if (version < 1) {
      throw const ApiContractException('policy.version.path');
    }
    final response = await _client.postJson(
      '/policy-consent/${type.apiValue}/versions/$version/accept',
      authenticated: true,
      body: const <String, Object?>{'confirmation': true},
    );
    final acceptance = PolicyAcceptance.fromJson(
      _dataMap(response.body, 'policy.acceptance'),
    );
    if (acceptance.type != type ||
        acceptance.version.version != version ||
        acceptance.version.status != 'published') {
      throw const ApiContractException('policy.acceptance.version');
    }
    return acceptance;
  }

  @override
  void clearPublicCache() {
    _currentCache.clear();
    _historyCache.clear();
    _versionCache.clear();
  }

  void _cacheVersion(String key, PolicyDocument document) {
    _versionCache.remove(key);
    _versionCache[key] = _Cached(document, _currentCacheTtl);
    while (_versionCache.length > _maxCachedEntries) {
      _versionCache.remove(_versionCache.keys.first);
    }
  }
}

class _Cached<T> {
  _Cached(this.value, Duration ttl) : expiresAt = DateTime.now().add(ttl);

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

Map<String, dynamic> _dataMap(String body, String field) {
  if (body.trim().isEmpty) {
    throw ApiContractException('$field.response');
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw ApiContractException('$field.response');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw ApiContractException('$field.data');
    }
    return Map<String, dynamic>.from(data);
  } on FormatException {
    throw ApiContractException('$field.response');
  }
}
