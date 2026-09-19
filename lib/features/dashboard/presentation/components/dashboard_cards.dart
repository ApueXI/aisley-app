part of '../dashboard_screen.dart';

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.courier, this.profilePhoto});

  final CourierIdentity courier;
  final ProfilePhotoData? profilePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final organization = courier.organizationName;
    final hub = courier.hubName;
    final affiliation = [?organization, ?hub].join(' • ');
    final photoBytes = profilePhoto?.bytes;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              child: photoBytes == null || photoBytes.isEmpty
                  ? Text(
                      _initials(courier.displayName),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )
                  : ClipOval(
                      child: Image.memory(
                        photoBytes,
                        key: const ValueKey<String>('dashboard-profile-photo'),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        semanticLabel: '${courier.displayName} profile photo',
                        errorBuilder: (context, error, stackTrace) => Text(
                          _initials(courier.displayName),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good to see you,',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    courier.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (affiliation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      affiliation,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionCard extends StatelessWidget {
  const _DashboardSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.section,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DashboardSection? section;

  @override
  Widget build(BuildContext context) {
    final resolvedSection =
        section ?? const DashboardSection(state: DashboardSectionState.unknown);
    final stateLabel = _stateLabel(resolvedSection);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '$title. $stateLabel',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _StatusPill(label: stateLabel),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _stateLabel(DashboardSection section) {
  return switch (section.state) {
    DashboardSectionState.available =>
      section.items.isEmpty ? 'No items available' : 'Available',
    DashboardSectionState.empty => 'Nothing to show',
    DashboardSectionState.unavailable => 'Unavailable in this build',
    DashboardSectionState.stale => 'Needs refresh',
    DashboardSectionState.failed => 'Could not load',
    DashboardSectionState.unknown => 'Unavailable',
  };
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
