part of '../final_mile_batch_screen.dart';

class _FinalMileBatchList extends StatelessWidget {
  const _FinalMileBatchList({
    required this.controller,
    required this.onOpenBatch,
    required this.onOpenPolicies,
    required this.canOpenPolicies,
  });

  final FinalMileBatchController controller;
  final ValueChanged<FinalMileBatch> onOpenBatch;
  final VoidCallback onOpenPolicies;
  final bool canOpenPolicies;

  @override
  Widget build(BuildContext context) {
    final batches = controller.batches;
    final status = controller.listStatus;
    if (batches.isEmpty && status == FinalMileBatchLoadStatus.loading) {
      return const _BatchScrollableState(
        semanticsLabel: 'Loading final-mile dispatch batches',
        child: CircularProgressIndicator(),
      );
    }
    if (batches.isEmpty && status == FinalMileBatchLoadStatus.empty) {
      return const _BatchScrollableState(
        child: Text(
          'No final-mile dispatch batches are assigned right now.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (batches.isEmpty && _isBatchBlocking(status)) {
      return _BatchErrorState(
        message: controller.listError ?? 'Dispatch batches are unavailable.',
        status: status,
        onRetry: controller.load,
        onOpenPolicies: onOpenPolicies,
        canOpenPolicies: canOpenPolicies,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Dispatch offers',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Review every parcel before accepting. One acceptance takes responsibility for the entire batch.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (_isBatchBlocking(status) && controller.listError != null) ...[
          const SizedBox(height: 12),
          _BatchInlineError(
            message: controller.listError!,
            onRetry: controller.load,
          ),
        ],
        const SizedBox(height: 18),
        for (final batch in batches) ...[
          _FinalMileBatchCard(batch: batch, onTap: () => onOpenBatch(batch)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FinalMileBatchCard extends StatelessWidget {
  const _FinalMileBatchCard({required this.batch, required this.onTap});

  final FinalMileBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destinations = batch.tasks
        .map((task) => task.destination.summary)
        .toSet()
        .take(2)
        .join(' • ');
    return Semantics(
      button: true,
      label:
          '${batch.reference}. ${batch.parcelCount} parcels. ${_batchStatusLabel(batch.status)}. Scheduled ${_formatBatchSchedule(batch.scheduledFor)}.',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.reference,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${batch.parcelCount} ${batch.parcelCount == 1 ? 'parcel' : 'parcels'} • ${_formatBatchSchedule(batch.scheduledFor)}',
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.outline),
                  ],
                ),
                if (destinations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    destinations,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                _BatchStatusChip(status: batch.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
