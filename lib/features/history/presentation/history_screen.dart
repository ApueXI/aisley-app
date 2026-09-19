import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/history_models.dart';
import 'history_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.authController,
    required this.historyController,
    this.policyController,
    super.key,
  });

  final AuthController authController;
  final HistoryController historyController;
  final PolicyController? policyController;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.historyController.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.historyController,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Delivery history')),
          body: RefreshIndicator(
            onRefresh: widget.historyController.load,
            child: _HistoryListBody(
              controller: widget.historyController,
              onOpenItem: _openItem,
              onRetry: widget.historyController.retry,
              onOpenPolicies: _openPolicies,
              showPolicyAction: widget.policyController != null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openItem(DeliveryHistoryItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryDetailScreen(
          authController: widget.authController,
          historyController: widget.historyController,
          item: item,
          policyController: widget.policyController,
        ),
      ),
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
      await widget.historyController.load();
    }
  }
}

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

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.label});

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

class _HistoryLoadingCard extends StatelessWidget {
  const _HistoryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading delivery history',
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No completed final-mile deliveries are available.'),
      ),
    );
  }
}

class _HistoryErrorCard extends StatelessWidget {
  const _HistoryErrorCard({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final HistoryLoadStatus status;
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
                if (_historyCanRetry(status))
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (status == HistoryLoadStatus.consentRequired &&
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

class _HistoryInlineError extends StatelessWidget {
  const _HistoryInlineError({required this.message, required this.onRetry});

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

bool _historyCanRetry(HistoryLoadStatus status) {
  return status == HistoryLoadStatus.offline ||
      status == HistoryLoadStatus.timeout ||
      status == HistoryLoadStatus.failed ||
      status == HistoryLoadStatus.rateLimited;
}

String _historyStatusLabel(String status) {
  return switch (status) {
    'delivered' => 'Delivered',
    _ => 'Status unavailable',
  };
}

String _areaRouteLabel(DeliveryHistoryItem item) {
  final pickup = item.pickupArea?.areaSummary;
  final destination = item.destinationArea?.areaSummary;
  if (pickup == null || pickup == 'Location unavailable') {
    return destination == null || destination == 'Location unavailable'
        ? 'Pickup and destination areas unavailable'
        : 'To $destination';
  }
  if (destination == null || destination == 'Location unavailable') {
    return 'From $pickup';
  }
  return '$pickup → $destination';
}

String _formatHistoryTimestamp(DateTime timestamp) {
  final value = timestamp.toLocal();
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute $period';
}
