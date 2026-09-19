part of '../delivery_screen.dart';

class _DeliveryIdentity extends StatelessWidget {
  const _DeliveryIdentity({required this.task});

  final PickupTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Final-mile delivery',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              task.order?.reference ?? 'Order reference unavailable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.waybill?.reference ?? 'Waybill reference unavailable',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            _DeliveryStatusPill(label: _deliveryStatusLabel(task.rawStatus)),
          ],
        ),
      ),
    );
  }
}

class _DeliveryContextCard extends StatelessWidget {
  const _DeliveryContextCard({
    required this.contextData,
    required this.status,
    required this.error,
    required this.onRetry,
  });

  final DeliveryContext? contextData;
  final DeliveryLoadStatus status;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if ((status == DeliveryLoadStatus.idle ||
            status == DeliveryLoadStatus.loading) &&
        contextData == null) {
      return const _DeliveryLoadingCard();
    }
    if (contextData == null) {
      return _DeliveryErrorCard(
        message: error ?? 'Delivery context is unavailable.',
        status: status,
        onRetry: onRetry,
        onOpenPolicies: () {},
        showPolicyAction: false,
      );
    }
    final data = contextData!;
    final destination = data.destination;
    final hub = data.hub;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery details',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _DeliveryDetailRow(
              label: 'Pickup hub',
              value: hub?.fullAddress ?? hub?.areaSummary ?? 'Hub unavailable',
            ),
            _DeliveryDetailRow(
              label: 'Destination',
              value:
                  destination?.fullAddress ??
                  destination?.areaSummary ??
                  'Destination unavailable',
            ),
            if (data.recipientName != null)
              _DeliveryDetailRow(
                label: 'Recipient',
                value: data.recipientName!,
              ),
            if (data.recipientPhone != null)
              _DeliveryDetailRow(
                label: 'Contact number',
                value: data.recipientPhone!,
              ),
            if (data.deliveryInstructions != null)
              _DeliveryDetailRow(
                label: 'Delivery instructions',
                value: data.deliveryInstructions!,
              ),
            const SizedBox(height: 6),
            _RouteMetrics(contextData: data),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteMetrics extends StatelessWidget {
  const _RouteMetrics({required this.contextData});

  final DeliveryContext contextData;

  @override
  Widget build(BuildContext context) {
    final metrics = <String>[
      if (contextData.distanceKm != null)
        'Advisory distance: ${contextData.distanceKm!.toStringAsFixed(1)} km',
      if (contextData.estimatedDurationMinutes != null)
        'Advisory duration: ${contextData.estimatedDurationMinutes} minutes',
    ];
    final routeStatus = contextData.routeStatus;
    final hasMetrics = metrics.isNotEmpty;
    final calculatedAt = contextData.calculatedAt;
    return Semantics(
      label: hasMetrics
          ? [
              ...metrics,
              if (calculatedAt != null)
                'calculated ${_formatTimestamp(calculatedAt)}',
            ].join('. ')
          : 'Route metrics unavailable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMetrics) ...[
            for (final metric in metrics) Text(metric),
            if (calculatedAt != null)
              Text(
                'Calculated ${_formatTimestamp(calculatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ] else
            Text(
              routeStatus == 'stale'
                  ? 'Route metrics are stale and advisory. Refresh before relying on them.'
                  : 'Route metrics unavailable. Continue with the authorized destination details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
