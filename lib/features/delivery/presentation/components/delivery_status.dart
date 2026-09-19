part of '../delivery_screen.dart';

class _BeforeHubPickupCard extends StatelessWidget {
  const _BeforeHubPickupCard({required this.onOpenPickup});

  final VoidCallback? onOpenPickup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hub pickup is next',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Accept the final-mile offer and submit hub handoff evidence in Pickup orders before starting delivery.',
            ),
            if (onOpenPickup != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onOpenPickup,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Open pickup orders'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedDeliveryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Semantics(
          liveRegion: true,
          label: 'Delivery completed',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline),
              SizedBox(height: 10),
              Text('Delivery completed'),
              SizedBox(height: 6),
              Text('The server marked this final-mile task delivered.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveredStatusText extends StatelessWidget {
  const _DeliveredStatusText();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Delivery completed by the server',
      child: Text('Delivery completed by the server.'),
    );
  }
}

class _AwaitingCompletionText extends StatelessWidget {
  const _AwaitingCompletionText();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Awaiting Logistics validation for completion',
      child: Text(
        'Completion intent accepted by the server. Awaiting Logistics validation. Refresh to see whether delivery was finalized.',
      ),
    );
  }
}

class _DeliveryDetailRow extends StatelessWidget {
  const _DeliveryDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label: '$label: $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStatusPill extends StatelessWidget {
  const _DeliveryStatusPill({required this.label});

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

class _DeliveryLoadingCard extends StatelessWidget {
  const _DeliveryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading delivery work',
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _DeliveryEmptyCard extends StatelessWidget {
  const _DeliveryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No final-mile deliveries are assigned right now.'),
      ),
    );
  }
}

class _DeliveryUnavailableActionCard extends StatelessWidget {
  const _DeliveryUnavailableActionCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'No delivery action is available for this server status. Refresh to check for an updated task state.',
        ),
      ),
    );
  }
}

class _DeliveryErrorCard extends StatelessWidget {
  const _DeliveryErrorCard({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final DeliveryLoadStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (_canRetryLoad(status))
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (status == DeliveryLoadStatus.consentRequired &&
                    showPolicyAction)
                  FilledButton.icon(
                    onPressed: onOpenPolicies,
                    icon: const Icon(Icons.policy_outlined),
                    label: const Text('Review policies'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryInlineError extends StatelessWidget {
  const _DeliveryInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

bool _canRetryLoad(DeliveryLoadStatus status) {
  return status == DeliveryLoadStatus.offline ||
      status == DeliveryLoadStatus.timeout ||
      status == DeliveryLoadStatus.failed ||
      status == DeliveryLoadStatus.rateLimited;
}

bool _canRetry(DeliveryActionStatus status) {
  return status == DeliveryActionStatus.offline ||
      status == DeliveryActionStatus.timeout ||
      status == DeliveryActionStatus.conflict ||
      status == DeliveryActionStatus.rateLimited ||
      status == DeliveryActionStatus.failed;
}

String _deliveryStatusLabel(String status) {
  return switch (status) {
    'delivery_assigned' => 'Assigned — accept before hub pickup',
    'delivery_accepted' => 'Accepted — ready for hub pickup',
    'picked_up_from_hub' => 'Picked up from hub',
    'in_transit' => 'In transit',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'rejected' => 'Offer rejected',
    _ => 'Status unavailable',
  };
}

String _formatTimestamp(DateTime timestamp) {
  final value = timestamp.toUtc().add(const Duration(hours: 8));
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute $period (Asia/Manila)';
}
