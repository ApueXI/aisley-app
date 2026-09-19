part of '../pickup_screen.dart';

class _PickupStatusLabel extends StatelessWidget {
  const _PickupStatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _taskStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PickupLoadingState extends StatelessWidget {
  const _PickupLoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading pickup work',
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _PickupEmptyState extends StatelessWidget {
  const _PickupEmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('No ${title.toLowerCase()} are assigned right now.'),
      ),
    );
  }
}

class _PickupErrorState extends StatelessWidget {
  const _PickupErrorState({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final PickupSectionStatus status;
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
                if (_isRecoverableStatus(status))
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (status == PickupSectionStatus.consentRequired &&
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

class _PickupInlineError extends StatelessWidget {
  const _PickupInlineError({
    required this.message,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (showPolicyAction)
            TextButton(
              onPressed: onOpenPolicies,
              child: const Text('Policies'),
            ),
        ],
      ),
    );
  }
}

bool _isBlockingStatus(PickupSectionStatus status) {
  return status != PickupSectionStatus.idle &&
      status != PickupSectionStatus.loading &&
      status != PickupSectionStatus.loaded &&
      status != PickupSectionStatus.empty;
}

bool _isRecoverableStatus(PickupSectionStatus status) {
  return status == PickupSectionStatus.offline ||
      status == PickupSectionStatus.timeout ||
      status == PickupSectionStatus.failed ||
      status == PickupSectionStatus.rateLimited;
}

String _taskLegLabel(PickupTask task) {
  return task.isFirstMile ? 'Seller pickup' : 'Hub pickup';
}

String _taskStatusLabel(String value) {
  return switch (value) {
    'assigned' => 'Assigned — accept before pickup',
    'accepted' => 'Accepted — ready to verify',
    'picked_up_from_seller' => 'Picked up from Seller',
    'delivery_assigned' => 'Assigned — accept before hub pickup',
    'delivery_accepted' => 'Accepted — ready to verify hub handoff',
    'picked_up_from_hub' => 'Picked up from hub',
    'in_transit' => 'In transit',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'rejected' => 'Offer rejected',
    'cancelled' => 'Cancelled',
    _ => 'Status unavailable',
  };
}

String? _formatWindow(PickupSchedule? schedule) {
  if (schedule == null ||
      (schedule.startsAt == null && schedule.endsAt == null)) {
    return null;
  }
  final start = schedule.startsAt == null
      ? null
      : _formatManilaTimestamp(schedule.startsAt!);
  final end = schedule.endsAt == null
      ? null
      : _formatManilaTimestamp(schedule.endsAt!);
  return [?start, if (end != null) 'to $end', 'Asia/Manila'].join(' ');
}

String _formatManilaTimestamp(DateTime timestamp) {
  final value = timestamp.toUtc().add(const Duration(hours: 8));
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour:$minute $period';
}
