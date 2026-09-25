part of '../dashboard_screen.dart';

class _DashboardTaskPreviews extends StatelessWidget {
  const _DashboardTaskPreviews({
    required this.controller,
    required this.onOpenFirstMile,
    required this.onOpenFinalMile,
  });

  final DashboardPreviewController controller;
  final VoidCallback onOpenFirstMile;
  final VoidCallback onOpenFinalMile;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Task previews', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Read-only work from the separate task lists.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _TaskPreviewSection(
            title: 'First-mile pickup',
            source: 'First-mile task list · first page',
            expectedLeg: PickupTaskLeg.firstMile,
            section: controller.firstMile,
            canRetry: controller.canRetryFirstMile,
            onRetry: controller.refreshFirstMile,
            onOpen: onOpenFirstMile,
          ),
          const SizedBox(height: 12),
          _TaskPreviewSection(
            title: 'Final-mile delivery',
            source: 'Final-mile task list · up to five rows',
            expectedLeg: PickupTaskLeg.finalMile,
            section: controller.finalMile,
            canRetry: controller.canRetryFinalMile,
            onRetry: controller.refreshFinalMile,
            onOpen: onOpenFinalMile,
          ),
        ],
      ),
    );
  }
}

class _TaskPreviewSection extends StatelessWidget {
  const _TaskPreviewSection({
    required this.title,
    required this.source,
    required this.expectedLeg,
    required this.section,
    required this.canRetry,
    required this.onRetry,
    required this.onOpen,
  });

  final String title;
  final String source;
  final PickupTaskLeg expectedLeg;
  final DashboardPreviewSection section;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = section.status;
    final isLoading = status == DashboardPreviewStatus.loading;
    final loadedAt = section.refreshedAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(source, style: Theme.of(context).textTheme.bodySmall),
                  if (loadedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last loaded ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(loadedAt.toLocal()))}${section.isStale ? ' · may be stale' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(
                      semanticsLabel: 'Refreshing task preview',
                    ),
                  ],
                  if (section.error case final message?) ...[
                    const SizedBox(height: 8),
                    Semantics(liveRegion: true, child: Text(message)),
                  ],
                  if (status == DashboardPreviewStatus.empty) ...[
                    const SizedBox(height: 8),
                    const Text('No tasks returned by this list.'),
                  ],
                  if (status == DashboardPreviewStatus.idle) ...[
                    const SizedBox(height: 8),
                    const Text('Task preview has not loaded yet.'),
                  ],
                ],
              ),
            ),
            for (final task in section.tasks) ...[
              const Divider(height: 16),
              _TaskPreviewRow(
                task: task,
                expectedLeg: expectedLeg,
                onOpen: onOpen,
              ),
            ],
            if (section.firstPageOnly)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('More first-mile tasks may be on later pages.'),
              ),
            if (section.error != null && canRetry)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text('Retry $title'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskPreviewRow extends StatelessWidget {
  const _TaskPreviewRow({
    required this.task,
    required this.expectedLeg,
    required this.onOpen,
  });

  final DashboardTaskPreview task;
  final PickupTaskLeg expectedLeg;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final classification = dashboardTaskClassification(task, expectedLeg);
    final orderReference = task.orderReference;
    final waybillReference = task.waybillReference;
    final label = orderReference != null
        ? 'Order $orderReference'
        : waybillReference != null
        ? 'Waybill $waybillReference'
        : 'Task reference unavailable';
    final origin = task.originName;
    final destination = task.destinationArea;
    final detail = [
      '${classification.label} · ${dashboardTaskStatusLabel(task)}',
      if (origin != null) 'From $origin',
      if (destination != null) 'To $destination',
      if (task.distanceKm case final km? when km >= 0)
        '${km.toStringAsFixed(1)} km',
      if (task.estimatedDurationMinutes case final minutes? when minutes >= 0)
        '$minutes min estimate',
    ].join(' · ');
    final canNavigate = classification != DashboardTaskClass.unclassified;

    return Semantics(
      button: canNavigate,
      label:
          '${expectedLeg == PickupTaskLeg.firstMile ? 'First-mile' : 'Final-mile'} task. $label. $detail${canNavigate ? '. Open work list' : '. Status requires review in work list'}',
      child: ListTile(
        title: Text(label),
        subtitle: Text(detail),
        trailing: canNavigate ? const Icon(Icons.chevron_right) : null,
        onTap: canNavigate ? onOpen : null,
      ),
    );
  }
}
