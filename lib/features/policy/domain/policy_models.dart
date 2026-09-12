import '../../../core/networking/api_contract_exception.dart';

enum PolicyType { termsOfService, privacyPolicy }

extension PolicyTypeX on PolicyType {
  String get apiValue => switch (this) {
    PolicyType.termsOfService => 'terms_of_service',
    PolicyType.privacyPolicy => 'privacy_policy',
  };

  String get fallbackLabel => switch (this) {
    PolicyType.termsOfService => 'Terms of Service',
    PolicyType.privacyPolicy => 'Privacy Policy',
  };
}

PolicyType? parsePolicyType(Object? value) {
  return switch (value) {
    'terms_of_service' => PolicyType.termsOfService,
    'privacy_policy' => PolicyType.privacyPolicy,
    _ => null,
  };
}

class PolicyVersion {
  const PolicyVersion({
    required this.id,
    required this.version,
    required this.title,
    required this.content,
    required this.status,
    required this.changeSummary,
    required this.requiresReconsent,
    required this.publishedAt,
  });

  final String id;
  final int version;
  final String title;
  final String content;
  final String status;
  final String? changeSummary;
  final bool requiresReconsent;
  final DateTime? publishedAt;

  factory PolicyVersion.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id'], 'policy.version.id');
    final version = _requiredInt(json['version'], 'policy.version.version');
    final title = _requiredString(json['title'], 'policy.version.title');
    final content = _requiredString(json['content'], 'policy.version.content');
    final status = _requiredString(json['status'], 'policy.version.status');
    final requiresReconsent = json['requires_reconsent'];
    if (requiresReconsent is! bool) {
      throw const ApiContractException('policy.version.requires_reconsent');
    }

    return PolicyVersion(
      id: id,
      version: version,
      title: title,
      content: content,
      status: status,
      changeSummary: _nullableString(json['change_summary']),
      requiresReconsent: requiresReconsent,
      publishedAt: _nullableDateTime(
        json['published_at'],
        'policy.version.published_at',
      ),
    );
  }
}

class PolicyDocument {
  const PolicyDocument({
    required this.type,
    required this.label,
    required this.version,
  });

  final PolicyType type;
  final String label;
  final PolicyVersion version;

  factory PolicyDocument.fromJson(Map<String, dynamic> json) {
    final type = parsePolicyType(json['type']);
    if (type == null) {
      throw const ApiContractException('policy.type.unsupported');
    }
    return PolicyDocument(
      type: type,
      label: _requiredString(json['label'], 'policy.label'),
      version: PolicyVersion.fromJson(
        _requiredMap(json['version'], 'policy.version'),
      ),
    );
  }
}

class PolicyHistoryEntry {
  const PolicyHistoryEntry({
    required this.id,
    required this.version,
    required this.title,
    required this.status,
    required this.changeSummary,
    required this.publishedAt,
  });

  final String id;
  final int version;
  final String title;
  final String status;
  final String? changeSummary;
  final DateTime? publishedAt;

  factory PolicyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PolicyHistoryEntry(
      id: _requiredString(json['id'], 'policy.history.id'),
      version: _requiredInt(json['version'], 'policy.history.version'),
      title: _requiredString(json['title'], 'policy.history.title'),
      status: _requiredString(json['status'], 'policy.history.status'),
      changeSummary: _nullableString(json['change_summary']),
      publishedAt: _nullableDateTime(
        json['published_at'],
        'policy.history.published_at',
      ),
    );
  }
}

class PolicyHistory {
  const PolicyHistory({
    required this.type,
    required this.label,
    required this.versions,
  });

  final PolicyType type;
  final String label;
  final List<PolicyHistoryEntry> versions;

  factory PolicyHistory.fromJson(Map<String, dynamic> json) {
    final type = parsePolicyType(json['type']);
    if (type == null) {
      throw const ApiContractException('policy.history.type.unsupported');
    }
    final versions = json['versions'];
    if (versions is! List) {
      throw const ApiContractException('policy.history.versions');
    }

    final entries = versions
        .map((item) {
          return PolicyHistoryEntry.fromJson(
            _requiredMap(item, 'policy.history.version'),
          );
        })
        .where(
          (entry) =>
              entry.status == 'published' || entry.status == 'superseded',
        )
        .toList(growable: false);

    return PolicyHistory(
      type: type,
      label: _requiredString(json['label'], 'policy.history.label'),
      versions: entries,
    );
  }
}

class PolicyConsentItem {
  const PolicyConsentItem({
    required this.rawType,
    required this.label,
    required this.required,
    required this.accepted,
    required this.acceptedAt,
    required this.currentVersion,
    required this.acceptedVersion,
  });

  final String rawType;
  final String label;
  final bool required;
  final bool accepted;
  final DateTime? acceptedAt;
  final int? currentVersion;
  final int? acceptedVersion;

  PolicyType? get type => parsePolicyType(rawType);

  bool get isSupported => type != null;

  factory PolicyConsentItem.fromJson(Map<String, dynamic> json) {
    final rawType = _requiredString(json['type'], 'policy.consent.type');
    final required = json['required'];
    final accepted = json['accepted'];
    if (required is! bool || accepted is! bool) {
      throw const ApiContractException('policy.consent.flags');
    }

    return PolicyConsentItem(
      rawType: rawType,
      label: _requiredString(json['label'], 'policy.consent.label'),
      required: required,
      accepted: accepted,
      acceptedAt: _nullableDateTime(
        json['accepted_at'],
        'policy.consent.accepted_at',
      ),
      currentVersion: _nullableInt(
        json['current_version'],
        'policy.consent.current_version',
      ),
      acceptedVersion: _nullableInt(
        json['accepted_version'],
        'policy.consent.accepted_version',
      ),
    );
  }
}

class PolicyConsentStatus {
  const PolicyConsentStatus({
    required this.policies,
    required this.allRequiredAccepted,
  });

  final List<PolicyConsentItem> policies;
  final bool allRequiredAccepted;

  Iterable<PolicyConsentItem> get supportedPolicies =>
      policies.where((item) => item.isSupported);

  PolicyConsentItem? itemFor(PolicyType type) {
    for (final item in policies) {
      if (item.type == type) {
        return item;
      }
    }
    return null;
  }

  factory PolicyConsentStatus.fromJson(Map<String, dynamic> json) {
    final policies = json['policies'];
    final allRequiredAccepted = json['all_required_accepted'];
    if (policies is! List || allRequiredAccepted is! bool) {
      throw const ApiContractException('policy.consent.response');
    }

    return PolicyConsentStatus(
      policies: policies
          .map((item) {
            return PolicyConsentItem.fromJson(
              _requiredMap(item, 'policy.consent.item'),
            );
          })
          .toList(growable: false),
      allRequiredAccepted: allRequiredAccepted,
    );
  }
}

class PolicyAcceptance {
  const PolicyAcceptance({
    required this.type,
    required this.label,
    required this.version,
    required this.acceptedAt,
  });

  final PolicyType type;
  final String label;
  final PolicyVersion version;
  final DateTime? acceptedAt;

  factory PolicyAcceptance.fromJson(Map<String, dynamic> json) {
    final type = parsePolicyType(json['type']);
    if (type == null) {
      throw const ApiContractException('policy.acceptance.type.unsupported');
    }
    return PolicyAcceptance(
      type: type,
      label: _requiredString(json['label'], 'policy.acceptance.label'),
      version: PolicyVersion.fromJson(
        _requiredMap(json['version'], 'policy.acceptance.version'),
      ),
      acceptedAt: _nullableDateTime(
        json['accepted_at'],
        'policy.acceptance.accepted_at',
      ),
    );
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ApiContractException(field);
  }
  return value;
}

int _requiredInt(Object? value, String field) {
  if (value is! int) {
    throw ApiContractException(field);
  }
  return value;
}

int? _nullableInt(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw ApiContractException(field);
  }
  return value;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const ApiContractException('policy.optional_string');
  }
  return value;
}

DateTime? _nullableDateTime(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ApiContractException(field);
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ApiContractException(field);
  }
  return parsed.toUtc();
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is! Map) {
    throw ApiContractException(field);
  }
  return Map<String, dynamic>.from(value);
}
