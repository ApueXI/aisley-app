part of '../pickup_screen.dart';

class _PickupListBody extends StatelessWidget {
  const _PickupListBody({
    required this.authController,
    required this.pickupController,
    required this.policyController,
    required this.onOpenTask,
    required this.onOpenRoute,
    required this.onOpenPolicies,
  });

  final AuthController authController;
  final PickupController pickupController;
  final PolicyController? policyController;
  final ValueChanged<PickupTask> onOpenTask;
  final ValueChanged<PickupTask> onOpenRoute;
  final VoidCallback onOpenPolicies;

  @override
  Widget build(BuildContext context) {
    final controller = pickupController;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Assigned pickup work',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Review the server assignment, accept it, then verify the waybill before confirming physical handoff.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _PickupSection(
          title: 'Seller pickups',
          subtitle: 'First-mile work from a Seller to your Logistics hub.',
          icon: Icons.storefront_outlined,
          status: controller.firstMileStatus,
          errorMessage: controller.firstMileErrorMessage,
          tasks: controller.firstMileTasks,
          page: controller.firstMilePage,
          onOpenTask: onOpenTask,
          onOpenRoute: onOpenRoute,
          onRetry: controller.load,
          onOpenPolicies: onOpenPolicies,
          showPolicyAction: policyController != null,
        ),
        const SizedBox(height: 24),
        _PickupSection(
          title: 'Hub pickups',
          subtitle: 'Final-mile work from your Logistics hub to the Buyer.',
          icon: Icons.local_shipping_outlined,
          status: controller.finalMileStatus,
          errorMessage: controller.finalMileErrorMessage,
          tasks: controller.finalMileTasks,
          onOpenTask: onOpenTask,
          onOpenRoute: null,
          onRetry: controller.load,
          onOpenPolicies: onOpenPolicies,
          showPolicyAction: policyController != null,
        ),
        if (!controller.hasLoadedAnySection && !controller.isLoading) ...[
          const SizedBox(height: 8),
          Text(
            'No pickup section is available yet. Pull to refresh when the service is reachable.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _PickupSection extends StatelessWidget {
  const _PickupSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.errorMessage,
    required this.tasks,
    required this.onOpenTask,
    required this.onOpenRoute,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
    this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PickupSectionStatus status;
  final String? errorMessage;
  final List<PickupTask> tasks;
  final FirstMileTaskPage? page;
  final ValueChanged<PickupTask> onOpenTask;
  final ValueChanged<PickupTask>? onOpenRoute;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupedTasks = _groupTasks(tasks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (status == PickupSectionStatus.loading && tasks.isEmpty)
          const _PickupLoadingState()
        else if (_isBlockingStatus(status) && tasks.isEmpty)
          _PickupErrorState(
            message: errorMessage ?? 'Pickup work is unavailable.',
            status: status,
            onRetry: onRetry,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: showPolicyAction,
          )
        else if (status == PickupSectionStatus.empty || tasks.isEmpty)
          _PickupEmptyState(title: title)
        else ...[
          for (final group in groupedTasks) ...[
            _ScheduleGroupHeader(
              task: group.first,
              onOpenRoute: onOpenRoute == null
                  ? null
                  : () => onOpenRoute!(group.first),
            ),
            const SizedBox(height: 8),
            for (final task in group) ...[
              _PickupTaskCard(task: task, onTap: () => onOpenTask(task)),
              const SizedBox(height: 8),
            ],
          ],
          if (page?.hasMore == true)
            Text(
              'More first-mile work is available on the server. Refresh to load the latest bounded list.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (_isRecoverableStatus(status) && errorMessage != null)
            _PickupInlineError(
              message: errorMessage!,
              onRetry: onRetry,
              onOpenPolicies: onOpenPolicies,
              showPolicyAction: showPolicyAction,
            ),
        ],
      ],
    );
  }
}

class _PickupTaskCard extends StatelessWidget {
  const _PickupTaskCard({required this.task, required this.onTap});

  final PickupTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = task.order?.displayReference ?? 'Order reference unavailable';
    final waybill =
        task.waybill?.displayReference ?? 'Waybill reference unavailable';
    final pickup = task.pickup;
    final destination = task.destinationArea?.areaSummary;
    final details = <String>[
      _taskLegLabel(task),
      _taskStatusLabel(task.rawStatus),
      'Order $order',
      'Waybill $waybill',
      if (pickup?.name != null) pickup!.name!,
      if (destination != null && destination != 'Location unavailable')
        'Destination: $destination',
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    task.isFirstMile
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
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
                        pickup?.name ?? _taskLegLabel(task),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination == null ||
                                destination == 'Location unavailable'
                            ? 'Destination area unavailable'
                            : 'To $destination',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      _PickupStatusLabel(status: task.rawStatus),
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

class _ScheduleGroupHeader extends StatelessWidget {
  const _ScheduleGroupHeader({required this.task, this.onOpenRoute});

  final PickupTask task;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final schedule = task.schedule;
    final scheduleLabel = schedule?.displayId;
    final window = _formatWindow(schedule);
    if (scheduleLabel == null && window == null && onOpenRoute == null) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            [
              if (scheduleLabel != null) 'Schedule $scheduleLabel',
              ?window,
            ].join(' • '),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (onOpenRoute != null)
          TextButton.icon(
            onPressed: onOpenRoute,
            icon: const Icon(Icons.route_outlined),
            label: const Text('Route order'),
          ),
      ],
    );
  }
}

List<List<PickupTask>> _groupTasks(List<PickupTask> tasks) {
  final groups = <String, List<PickupTask>>{};
  for (final task in tasks) {
    final key = task.pickupScheduleId ?? task.schedule?.id ?? task.id;
    groups.putIfAbsent(key, () => <PickupTask>[]).add(task);
  }
  return groups.values.toList(growable: false);
}
