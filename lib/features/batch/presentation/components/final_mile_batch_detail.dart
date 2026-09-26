part of '../final_mile_batch_screen.dart';

class FinalMileBatchDetailScreen extends StatefulWidget {
  const FinalMileBatchDetailScreen({
    required this.authController,
    required this.batchController,
    required this.scheduleId,
    this.policyController,
    super.key,
  });

  final AuthController authController;
  final FinalMileBatchController batchController;
  final String scheduleId;
  final PolicyController? policyController;

  @override
  State<FinalMileBatchDetailScreen> createState() =>
      _FinalMileBatchDetailScreenState();
}

class _FinalMileBatchDetailScreenState
    extends State<FinalMileBatchDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.batchController.loadDetail(widget.scheduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.batchController,
      builder: (context, child) {
        final controller = widget.batchController;
        final batch = controller.batchById(widget.scheduleId);
        final detailStatus = controller.detailStatus(widget.scheduleId);
        if (batch == null &&
            (detailStatus == FinalMileBatchLoadStatus.idle ||
                detailStatus == FinalMileBatchLoadStatus.loading)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dispatch batch')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (batch == null ||
            detailStatus == FinalMileBatchLoadStatus.unavailable ||
            detailStatus == FinalMileBatchLoadStatus.forbidden ||
            detailStatus == FinalMileBatchLoadStatus.unauthorized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dispatch batch')),
            body: _BatchErrorState(
              message:
                  controller.detailError(widget.scheduleId) ??
                  'This dispatch batch is unavailable.',
              status: detailStatus,
              onRetry: () => controller.loadDetail(widget.scheduleId),
              onOpenPolicies: _openPolicies,
              canOpenPolicies: widget.policyController != null,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Dispatch batch')),
          body: RefreshIndicator(
            onRefresh: () => controller.loadDetail(widget.scheduleId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _BatchSummary(batch: batch),
                if (_isBatchBlocking(detailStatus) &&
                    controller.detailError(widget.scheduleId) != null) ...[
                  const SizedBox(height: 12),
                  _BatchInlineError(
                    message: controller.detailError(widget.scheduleId)!,
                    onRetry: () => controller.loadDetail(widget.scheduleId),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Parcels',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < batch.tasks.length; index++) ...[
                  _BatchParcelCard(
                    position: index + 1,
                    task: batch.tasks[index],
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                _BatchAcceptanceCard(
                  batch: batch,
                  controller: controller,
                  onAccept: () => _confirmAcceptance(batch),
                  onRefresh: () => controller.loadDetail(widget.scheduleId),
                  onOpenPolicies: _openPolicies,
                  canOpenPolicies: widget.policyController != null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAcceptance(FinalMileBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this entire batch?'),
        content: Text(
          'You will accept responsibility for all ${batch.parcelCount} ${batch.parcelCount == 1 ? 'parcel' : 'parcels'} in ${batch.reference}. This does not record hub pickup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept entire batch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final accepted = await widget.batchController.accept(batch.id);
    if (!mounted || !accepted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Accepted all ${batch.parcelCount} parcels. Pickup and delivery work were refreshed.',
        ),
      ),
    );
  }

  Future<void> _openPolicies() async {
    final policies = widget.policyController;
    if (policies == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policies,
        ),
      ),
    );
    if (mounted) {
      await widget.batchController.loadDetail(widget.scheduleId);
    }
  }
}

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.batch});

  final FinalMileBatch batch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    batch.reference,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _BatchStatusChip(status: batch.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${batch.parcelCount} ${batch.parcelCount == 1 ? 'parcel' : 'parcels'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Scheduled ${_formatBatchSchedule(batch.scheduledFor)}'),
          ],
        ),
      ),
    );
  }
}

class _BatchParcelCard extends StatelessWidget {
  const _BatchParcelCard({required this.position, required this.task});

  final int position;
  final FinalMileBatchTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reference =
        task.orderReference ?? task.parcel.reference ?? 'Reference unavailable';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 18, child: Text('$position')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reference,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(task.destination.summary),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _BatchParcelFact(
                        icon: Icons.shopping_bag_outlined,
                        label: task.parcel.itemSummary,
                      ),
                      _BatchParcelFact(
                        icon: Icons.sell_outlined,
                        label: 'Parcel price: ${task.parcel.priceSummary}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Parcel price is the merchandise subtotal, not cash due on delivery.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchParcelFact extends StatelessWidget {
  const _BatchParcelFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 5),
        Flexible(child: Text(label)),
      ],
    );
  }
}
