class DashboardSnapshot {
  const DashboardSnapshot({
    required this.sections,
    required this.freshness,
    this.generatedAt,
  });

  final Map<String, DashboardSection> sections;
  final DashboardFreshness freshness;
  final String? generatedAt;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final sections = <String, DashboardSection>{};

    if (rawSections is Map) {
      for (final entry in rawSections.entries) {
        if (entry.value is Map) {
          sections[entry.key.toString()] = DashboardSection.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    final rawFreshness = json['freshness'];
    final freshness = rawFreshness is Map
        ? DashboardFreshness.fromJson(Map<String, dynamic>.from(rawFreshness))
        : const DashboardFreshness(state: DashboardFreshnessState.unknown);

    final generatedAt = json['meta'] is Map
        ? (json['meta'] as Map)['generated_at']?.toString()
        : null;

    return DashboardSnapshot(
      sections: sections,
      freshness: freshness,
      generatedAt: generatedAt,
    );
  }

  DashboardSection section(String key) {
    return sections[key] ??
        const DashboardSection(state: DashboardSectionState.unknown);
  }
}

enum DashboardSectionState {
  available,
  empty,
  unavailable,
  stale,
  failed,
  unknown,
}

class DashboardSection {
  const DashboardSection({
    required this.state,
    this.reason,
    this.items = const <Map<String, dynamic>>[],
  });

  final DashboardSectionState state;
  final String? reason;
  final List<Map<String, dynamic>> items;

  factory DashboardSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['data'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return DashboardSection(
      state: _parseSectionState(json['state']),
      reason: json['reason']?.toString(),
      items: items,
    );
  }
}

enum DashboardFreshnessState { fresh, stale, scaffold, unknown }

class DashboardFreshness {
  const DashboardFreshness({
    required this.state,
    this.reason,
    this.generatedAt,
  });

  final DashboardFreshnessState state;
  final String? reason;
  final String? generatedAt;

  factory DashboardFreshness.fromJson(Map<String, dynamic> json) {
    return DashboardFreshness(
      state: _parseFreshnessState(json['state']),
      reason: json['reason']?.toString(),
      generatedAt: json['generated_at']?.toString(),
    );
  }
}

DashboardSectionState _parseSectionState(Object? value) {
  return switch (value) {
    'available' => DashboardSectionState.available,
    'empty' => DashboardSectionState.empty,
    'unavailable' => DashboardSectionState.unavailable,
    'stale' => DashboardSectionState.stale,
    'failed' => DashboardSectionState.failed,
    _ => DashboardSectionState.unknown,
  };
}

DashboardFreshnessState _parseFreshnessState(Object? value) {
  return switch (value) {
    'fresh' => DashboardFreshnessState.fresh,
    'stale' => DashboardFreshnessState.stale,
    'scaffold' => DashboardFreshnessState.scaffold,
    _ => DashboardFreshnessState.unknown,
  };
}
