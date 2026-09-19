part of '../history_screen.dart';

class _HistoryListBody extends StatelessWidget {
  const _HistoryListBody({
    required this.controller,
    required this.onOpenItem,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final HistoryController controller;
  final ValueChanged<DeliveryHistoryItem> onOpenItem;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final items = controller.items;
    final blocking =
        status != HistoryLoadStatus.idle &&
        status != HistoryLoadStatus.loading &&
        status != HistoryLoadStatus.loaded &&
        status != HistoryLoadStatus.empty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Completed deliveries',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Read-only records of final-mile deliveries completed under your Courier assignment.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        if ((status == HistoryLoadStatus.idle ||
                status == HistoryLoadStatus.loading) &&
            items.isEmpty)
          const _HistoryLoadingCard()
        else if (blocking && items.isEmpty)
          _HistoryErrorCard(
            message:
                controller.errorMessage ?? 'Delivery history is unavailable.',
            status: status,
            onRetry: onRetry,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: showPolicyAction,
          )
        else if (status == HistoryLoadStatus.empty || items.isEmpty)
          const _HistoryEmptyCard()
        else ...[
          for (final item in items) ...[
            _HistoryItemCard(item: item, onTap: () => onOpenItem(item)),
            const SizedBox(height: 10),
          ],
          if (controller.errorMessage != null)
            _HistoryInlineError(
              message: controller.errorMessage!,
              onRetry: onRetry,
            ),
          if (controller.hasMore) ...[
            const SizedBox(height: 12),
            Text(
              controller.nextCursor == null
                  ? 'More history is available on the server, but the response did not provide a usable cursor.'
                  : 'More history is available, but this client does not request an undocumented cursor.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.item, required this.onTap});

  final DeliveryHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = item.order?.displayReference ?? 'Order reference unavailable';
    final pickup = item.pickupArea?.areaSummary;
    final destination = item.destinationArea?.areaSummary;
    final summary = <String>[
      'Completed delivery $order',
      if (item.deliveredAt != null)
        'Delivered ${_formatHistoryTimestamp(item.deliveredAt!)}',
      if (pickup != null && pickup != 'Location unavailable') 'From $pickup',
      if (destination != null && destination != 'Location unavailable')
        'To $destination',
      if (item.itemCount != null) '${item.itemCount} item(s)',
    ];
    return Semantics(
      button: true,
      label: summary.join('. '),
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
                    Icons.history_outlined,
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
                        item.deliveredAt == null
                            ? 'Delivered time unavailable'
                            : _formatHistoryTimestamp(item.deliveredAt!),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _areaRouteLabel(item),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _HistoryStatusPill(
                        label: _historyStatusLabel(item.status),
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
