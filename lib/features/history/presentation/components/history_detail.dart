part of '../history_screen.dart';

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({
    required this.authController,
    required this.historyController,
    required this.item,
    this.policyController,
    super.key,
  });

  final AuthController authController;
  final HistoryController historyController;
  final DeliveryHistoryItem item;
  final PolicyController? policyController;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.historyController.loadDetail(widget.item.taskId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.historyController,
      builder: (context, child) {
        final controller = widget.historyController;
        final loaded = controller.detail?.taskId == widget.item.taskId
            ? controller.detail
            : null;
        final item = loaded ?? widget.item;
        final status = controller.detail?.taskId == widget.item.taskId
            ? controller.detailStatus
            : HistoryLoadStatus.loading;
        final error = controller.detail?.taskId == widget.item.taskId
            ? controller.detailErrorMessage
            : null;
        return Scaffold(
          appBar: AppBar(title: const Text('Delivery record')),
          body: RefreshIndicator(
            onRefresh: () => controller.loadDetail(widget.item.taskId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _HistoryDetailIdentity(item: item),
                const SizedBox(height: 16),
                if (status == HistoryLoadStatus.loading && loaded == null)
                  const _HistoryLoadingCard()
                else if (error != null)
                  _HistoryErrorCard(
                    message: error,
                    status: status,
                    onRetry: () => controller.loadDetail(widget.item.taskId),
                    onOpenPolicies: _openPolicies,
                    showPolicyAction: widget.policyController != null,
                  )
                else
                  _HistoryDetailCard(item: item),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPolicies() async {
    final policyController = widget.policyController;
    if (policyController == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policyController,
        ),
      ),
    );
    if (mounted) {
      await widget.historyController.loadDetail(widget.item.taskId);
    }
  }
}

class _HistoryDetailIdentity extends StatelessWidget {
  const _HistoryDetailIdentity({required this.item});

  final DeliveryHistoryItem item;

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
              'Completed final-mile delivery',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.order?.displayReference ?? 'Order reference unavailable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _HistoryStatusPill(label: _historyStatusLabel(item.status)),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailCard extends StatelessWidget {
  const _HistoryDetailCard({required this.item});

  final DeliveryHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery summary',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _HistoryDetailRow(
              label: 'Delivered',
              value: item.deliveredAt == null
                  ? 'Time unavailable'
                  : _formatHistoryTimestamp(item.deliveredAt!),
            ),
            _HistoryDetailRow(
              label: 'Pickup area',
              value: item.pickupArea?.areaSummary ?? 'Area unavailable',
            ),
            _HistoryDetailRow(
              label: 'Destination area',
              value: item.destinationArea?.areaSummary ?? 'Area unavailable',
            ),
            if (item.parcelReference != null)
              _HistoryDetailRow(
                label: 'Parcel reference',
                value: item.parcelReference!,
              ),
            if (item.itemCount != null)
              _HistoryDetailRow(
                label: 'Item count',
                value: '${item.itemCount}',
              ),
            if (item.distanceKm != null)
              _HistoryDetailRow(
                label: 'Stored distance',
                value: '${item.distanceKm!.toStringAsFixed(1)} km',
              ),
            if (item.estimatedDurationMinutes != null)
              _HistoryDetailRow(
                label: 'Stored duration',
                value: '${item.estimatedDurationMinutes} minutes',
              ),
            const Divider(height: 28),
            Text(
              'Validation record',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _HistoryDetailRow(
              label: 'Proof status',
              value: item.evidenceStatus ?? 'Status unavailable',
            ),
            _HistoryDetailRow(
              label: 'Completion status',
              value: item.completionStatus ?? 'Status unavailable',
            ),
            if (item.evidenceId != null)
              _HistoryDetailRow(
                label: 'Proof reference',
                value: item.evidenceId!,
              ),
            if (item.items.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Item snapshots',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final snapshot in item.items)
                _HistoryDetailRow(
                  label: snapshot.name ?? 'Item name unavailable',
                  value: snapshot.quantity == null
                      ? 'Quantity unavailable'
                      : 'Quantity ${snapshot.quantity}',
                ),
            ],
            const SizedBox(height: 8),
            Text(
              'This record is read-only. The delivery event was committed by the server after Logistics validation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailRow extends StatelessWidget {
  const _HistoryDetailRow({required this.label, required this.value});

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
