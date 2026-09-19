part of '../policy_screen.dart';

class _PolicyLoadingView extends StatelessWidget {
  const _PolicyLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Loading policy and consent information',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _PolicyStateView extends StatelessWidget {
  const _PolicyStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPublishedPolicyView extends StatelessWidget {
  const _NoPublishedPolicyView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'No published policy version is available',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'There is no published policy version to display right now.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _AcceptedPolicyLabel extends StatelessWidget {
  const _AcceptedPolicyLabel({required this.item, required this.version});

  final PolicyConsentItem item;
  final int? version;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${item.label} version $version is accepted',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Accepted version $version${item.acceptedAt == null ? '' : ' on ${_formatDate(context, item.acceptedAt)}'}.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError
                ? scheme.onErrorContainer
                : scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return 'time unavailable';
  }
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date, $time';
}

String _statusLabel(String status) {
  return switch (status) {
    'published' => 'Published',
    'superseded' => 'Superseded',
    _ => 'Unavailable',
  };
}
