part of '../delivery_screen.dart';

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.task,
    required this.controller,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final PickupTask task;
  final DeliveryController controller;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final nextStatus = DeliveryController.nextStatusFor(task.status);
    final actionStatus = controller.actionStatus(task);
    final error = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final actionBlocked = !controller.canStartAction(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.status == PickupTaskStatus.pickedUpFromHub
                  ? 'Start delivery'
                  : 'Continue delivery',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              task.status == PickupTaskStatus.pickedUpFromHub
                  ? 'The server recorded hub custody. Confirm when this parcel is entering transit.'
                  : 'The server recorded transit. Confirm when the parcel is out for delivery.',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (actionStatus == DeliveryActionStatus.consentRequired &&
                  showPolicyAction)
                TextButton.icon(
                  onPressed: onOpenPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetry(actionStatus))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.loadDetails(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh task'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus != DeliveryActionStatus.conflict &&
                  controller.hasPendingMovement(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryMovement(task),
                  icon: const Icon(Icons.replay),
                  label: const Text('Retry same movement'),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy || actionBlocked || nextStatus == null
                  ? null
                  : () => _confirmMovement(context, nextStatus),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                nextStatus == 'in_transit'
                    ? 'Mark in transit'
                    : 'Mark out for delivery',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmMovement(BuildContext context, String nextStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nextStatus == 'in_transit'
              ? 'Start transit?'
              : 'Mark out for delivery?',
        ),
        content: const Text(
          'This submits the next server-authorized delivery state. It does not complete the delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final moved = await controller.advanceStatus(task);
      if (nextStatus == 'out_for_delivery') {
        if (moved) {
          await controller.loadCompletion(controller.taskById(task.id) ?? task);
        }
      }
    }
  }
}
