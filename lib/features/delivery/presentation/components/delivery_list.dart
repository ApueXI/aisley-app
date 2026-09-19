part of '../delivery_screen.dart';

class _DeliveryListBody extends StatelessWidget {
  const _DeliveryListBody({
    required this.controller,
    required this.onOpenTask,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final DeliveryController controller;
  final ValueChanged<PickupTask> onOpenTask;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final status = controller.loadStatus;
    final tasks = controller.tasks;
    final isBlocking =
        status != DeliveryLoadStatus.idle &&
        status != DeliveryLoadStatus.loading &&
        status != DeliveryLoadStatus.loaded &&
        status != DeliveryLoadStatus.empty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Final-mile deliveries',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Move only the delivery assigned to you. The server confirms every state and handoff.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        if ((status == DeliveryLoadStatus.idle ||
                status == DeliveryLoadStatus.loading) &&
            tasks.isEmpty)
          const _DeliveryLoadingCard()
        else if (isBlocking && tasks.isEmpty)
          _DeliveryErrorCard(
            message: controller.errorMessage ?? 'Delivery work is unavailable.',
            status: status,
            onRetry: onRetry,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: showPolicyAction,
          )
        else if (status == DeliveryLoadStatus.empty || tasks.isEmpty)
          const _DeliveryEmptyCard()
        else ...[
          for (final task in tasks) ...[
            _DeliveryTaskCard(task: task, onTap: () => onOpenTask(task)),
            const SizedBox(height: 10),
          ],
          if (controller.errorMessage != null)
            _DeliveryInlineError(
              message: controller.errorMessage!,
              onRetry: onRetry,
            ),
        ],
      ],
    );
  }
}

class _DeliveryTaskCard extends StatelessWidget {
  const _DeliveryTaskCard({required this.task, required this.onTap});

  final PickupTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destination = task.destinationArea?.areaSummary;
    final order = task.order?.reference ?? 'Order reference unavailable';
    final details = <String>[
      'Final-mile delivery',
      _deliveryStatusLabel(task.rawStatus),
      'Order $order',
      if (destination != null && destination != 'Location unavailable')
        'Destination $destination',
    ];
    return Semantics(
      button: true,
      label: details.join('. '),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination == null ||
                                destination == 'Location unavailable'
                            ? 'Destination area unavailable'
                            : 'To $destination',
                      ),
                      const SizedBox(height: 10),
                      _DeliveryStatusPill(
                        label: _deliveryStatusLabel(task.rawStatus),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
