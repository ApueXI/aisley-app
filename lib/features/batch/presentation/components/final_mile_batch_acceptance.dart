part of '../final_mile_batch_screen.dart';

class _BatchAcceptanceCard extends StatelessWidget {
  const _BatchAcceptanceCard({
    required this.batch,
    required this.controller,
    required this.onAccept,
    required this.onRefresh,
    required this.onOpenPolicies,
    required this.canOpenPolicies,
  });

  final FinalMileBatch batch;
  final FinalMileBatchController controller;
  final VoidCallback onAccept;
  final VoidCallback onRefresh;
  final VoidCallback onOpenPolicies;
  final bool canOpenPolicies;

  @override
  Widget build(BuildContext context) {
    final status = controller.actionStatus(batch.id);
    final error = controller.actionError(batch.id);
    final busy = controller.isActionBusy(batch.id);
    final scheme = Theme.of(context).colorScheme;

    if (batch.isAccepted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                batch.status == FinalMileBatchStatus.inProgress
                    ? 'Batch in progress'
                    : 'Entire batch accepted',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Each parcel remains a separate task. Acceptance does not record hub pickup; continue from Pickup orders when Logistics is ready.',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Accept all parcels',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'This one action accepts all ${batch.parcelCount} parcels atomically. Parcels cannot be accepted individually.',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            if (status == FinalMileBatchActionStatus.timeout ||
                status == FinalMileBatchActionStatus.offline ||
                status == FinalMileBatchActionStatus.failed)
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => controller.retryAcceptance(batch.id),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('Check result and retry'),
              )
            else if (status == FinalMileBatchActionStatus.conflict)
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh batch'),
              )
            else if (status == FinalMileBatchActionStatus.consentRequired &&
                canOpenPolicies)
              FilledButton.icon(
                onPressed: onOpenPolicies,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Review policies'),
              )
            else if (status != FinalMileBatchActionStatus.unavailable &&
                status != FinalMileBatchActionStatus.unauthorized &&
                status != FinalMileBatchActionStatus.forbidden)
              FilledButton.icon(
                onPressed: busy || !controller.canRetryRateLimit
                    ? null
                    : onAccept,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(busy ? 'Checking batch…' : 'Accept entire batch'),
              ),
          ],
        ),
      ),
    );
  }
}
