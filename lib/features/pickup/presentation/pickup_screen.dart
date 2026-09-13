import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/pickup_models.dart';
import 'pickup_controller.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({
    required this.authController,
    required this.pickupController,
    this.policyController,
    this.onOpenDelivery,
    super.key,
  });

  final AuthController authController;
  final PickupController pickupController;
  final PolicyController? policyController;
  final VoidCallback? onOpenDelivery;

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.pickupController.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pickupController,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pickup orders')),
          body: RefreshIndicator(
            onRefresh: widget.pickupController.load,
            child: _PickupListBody(
              authController: widget.authController,
              pickupController: widget.pickupController,
              policyController: widget.policyController,
              onOpenTask: _openTask,
              onOpenRoute: _openRoute,
              onOpenPolicies: _openPolicies,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTask(PickupTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickupTaskDetailScreen(
          authController: widget.authController,
          pickupController: widget.pickupController,
          policyController: widget.policyController,
          task: task,
          onOpenDelivery: widget.onOpenDelivery,
        ),
      ),
    );
  }

  Future<void> _openRoute(PickupTask task) async {
    final scheduleId = task.pickupScheduleId ?? task.schedule?.id;
    if (scheduleId == null || scheduleId.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickupRouteScreen(
          pickupController: widget.pickupController,
          scheduleId: scheduleId,
          schedule: task.schedule,
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
      await widget.pickupController.load();
    }
  }
}

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

class _PickupStatusLabel extends StatelessWidget {
  const _PickupStatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _taskStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PickupLoadingState extends StatelessWidget {
  const _PickupLoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading pickup work',
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _PickupEmptyState extends StatelessWidget {
  const _PickupEmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('No ${title.toLowerCase()} are assigned right now.'),
      ),
    );
  }
}

class _PickupErrorState extends StatelessWidget {
  const _PickupErrorState({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final PickupSectionStatus status;
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
                if (_isRecoverableStatus(status))
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (status == PickupSectionStatus.consentRequired &&
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

class _PickupInlineError extends StatelessWidget {
  const _PickupInlineError({
    required this.message,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (showPolicyAction)
            TextButton(
              onPressed: onOpenPolicies,
              child: const Text('Policies'),
            ),
        ],
      ),
    );
  }
}

class PickupTaskDetailScreen extends StatefulWidget {
  const PickupTaskDetailScreen({
    required this.authController,
    required this.pickupController,
    required this.task,
    this.policyController,
    this.onOpenDelivery,
    super.key,
  });

  final AuthController authController;
  final PickupController pickupController;
  final PickupTask task;
  final PolicyController? policyController;
  final VoidCallback? onOpenDelivery;

  @override
  State<PickupTaskDetailScreen> createState() => _PickupTaskDetailScreenState();
}

class _PickupTaskDetailScreenState extends State<PickupTaskDetailScreen> {
  final _identifierController = TextEditingController();
  String _identifierType = 'qr';
  bool? _resolvedForThisTask;
  String? _resolutionMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pickupController,
      builder: (context, child) {
        final task = widget.pickupController.taskWithId(widget.task);
        return Scaffold(
          appBar: AppBar(title: const Text('Pickup order')),
          body: RefreshIndicator(
            onRefresh: () => _refreshTask(task),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _TaskIdentity(task: task),
                const SizedBox(height: 16),
                _TaskDetails(task: task),
                const SizedBox(height: 16),
                _buildAction(context, task),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAction(BuildContext context, PickupTask task) {
    if (task.isFinalMile && task.status == PickupTaskStatus.rejected) {
      return _buildRejected(context, task);
    }
    if (task.hasBeenPickedUp) {
      return _CompletedPickup(
        task: task,
        controller: widget.pickupController,
        onOpenDelivery: widget.onOpenDelivery,
      );
    }
    if (task.isAssigned) {
      return _buildAcceptance(context, task);
    }
    if (task.isAccepted) {
      return _buildVerification(context, task);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'This task is not currently eligible for a pickup action. Refresh to see the server-authoritative state.',
        ),
      ),
    );
  }

  Widget _buildRejected(BuildContext context, PickupTask task) {
    final scheme = Theme.of(context).colorScheme;
    final actionStatus = widget.pickupController.actionStatus(task);
    final error = widget.pickupController.actionError(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_returned_outlined),
            const SizedBox(height: 10),
            Text(
              'Offer rejected',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              task.rejectionReason == null
                  ? 'Logistics may offer this task again.'
                  : 'Reason: ${task.rejectionReason}',
            ),
            if (task.offerRespondedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Recorded ${_formatManilaTimestamp(task.offerRespondedAt!)}',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (_canRetryAction(actionStatus) &&
                  widget.pickupController.hasPendingRejection(task))
                TextButton.icon(
                  onPressed: () => _retryRejection(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same rejection'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptance(BuildContext context, PickupTask task) {
    final controller = widget.pickupController;
    final actionStatus = controller.actionStatus(task);
    final error = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accept before pickup',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Opening this task does not accept it. Confirm that you are taking responsibility for this assigned ${task.isFirstMile ? 'Seller pickup' : 'hub delivery'} before verifying the parcel.',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (actionStatus == PickupTaskActionStatus.consentRequired &&
                  widget.policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetryAction(actionStatus) &&
                  controller.hasPendingRejection(task))
                TextButton.icon(
                  onPressed: busy ? null : () => _retryRejection(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same rejection'),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () => _confirmAcceptTask(task),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                task.isFirstMile
                    ? 'Accept Seller pickup'
                    : 'Accept hub delivery',
              ),
            ),
            if (task.isFinalMile) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: busy ? null : () => _confirmRejectTask(task),
                icon: const Icon(Icons.close),
                label: const Text('Reject offer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerification(BuildContext context, PickupTask task) {
    final controller = widget.pickupController;
    final actionStatus = controller.actionStatus(task);
    final actionError = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final isFinalMile = task.isFinalMile;
    final canSubmit = task.isFirstMile || task.revision != null;
    final scheme = Theme.of(context).colorScheme;
    final pendingFinalSubmission =
        isFinalMile &&
        actionStatus == PickupTaskActionStatus.awaitingValidation &&
        controller.lastFinalMilePickup?.taskId == task.id;
    final verificationLocked = busy || pendingFinalSubmission;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFinalMile ? 'Verify hub handoff' : 'Verify Seller handoff',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isFinalMile
                  ? 'Submit the waybill identifier as evidence. Logistics must validate it before the task becomes picked up from the hub.'
                  : 'Use the waybill QR payload or the printed Order ID/reference. Verification only prepares a candidate; the button below is the physical pickup confirmation.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'qr',
                  label: Text('Waybill QR'),
                  icon: Icon(Icons.qr_code_2),
                ),
                ButtonSegment<String>(
                  value: 'order_id',
                  label: Text('Order ID/reference'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: <String>{_identifierType},
              onSelectionChanged: verificationLocked
                  ? null
                  : (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      setState(() {
                        _identifierType = selection.first;
                        _resolvedForThisTask = null;
                        _resolutionMessage = null;
                      });
                      controller.clearResolution();
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _identifierController,
              enabled: !verificationLocked,
              maxLength: 128,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: _identifierType == 'qr'
                    ? 'Waybill QR payload'
                    : 'Printed Order ID/reference',
                helperText: _identifierType == 'qr'
                    ? 'A scanner keyboard or paste may enter the decoded payload. It is treated as untrusted text.'
                    : 'Enter the human-readable reference printed on the waybill.',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_resolvedForThisTask != null ||
                    _resolutionMessage != null) {
                  setState(() {
                    _resolvedForThisTask = null;
                    _resolutionMessage = null;
                  });
                  controller.clearResolution();
                }
              },
            ),
            if (_identifierType == 'qr') ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: verificationLocked || !controller.canRetryRateLimit
                    ? null
                    : _resolveQr,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Check QR match'),
              ),
            ],
            if (_resolutionMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _resolutionMessage!,
                style: TextStyle(
                  color: _resolvedForThisTask == true
                      ? scheme.primary
                      : scheme.error,
                ),
              ),
              if (controller.waybillResolutionStatus ==
                      PickupSectionStatus.consentRequired &&
                  widget.policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
            ],
            if (actionError != null) ...[
              const SizedBox(height: 12),
              Text(actionError, style: TextStyle(color: scheme.error)),
              if (actionStatus == PickupTaskActionStatus.consentRequired &&
                  widget.policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetryAction(actionStatus) &&
                  controller.hasPendingAttempt(task))
                TextButton.icon(
                  onPressed:
                      busy ||
                          (actionStatus == PickupTaskActionStatus.rateLimited &&
                              !controller.canRetryRateLimit)
                      ? null
                      : () => _retryPickup(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same attempt'),
                ),
            ],
            if (pendingFinalSubmission) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Awaiting Logistics validation for hub pickup',
                child: Text(
                  'Awaiting Logistics validation. Do not treat this submission as picked up from the hub yet.',
                  style: TextStyle(color: scheme.primary),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy || !canSubmit
                    ? null
                    : () => _submitPickup(task),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isFinalMile
                            ? Icons.upload_outlined
                            : Icons.check_circle_outline,
                      ),
                label: Text(
                  isFinalMile ? 'Submit hub pickup evidence' : 'Confirm pickup',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAcceptTask(PickupTask task) async {
    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Accept this task?'),
          content: Text(
            'Accepting confirms responsibility for this ${task.isFirstMile ? 'Seller pickup' : 'hub delivery'}. It does not record physical pickup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept task'),
            ),
          ],
        );
      },
    );
    if (shouldAccept != true || !mounted) {
      return;
    }
    await widget.pickupController.acceptTask(task);
    await _closeIfSessionEnded();
  }

  Future<void> _confirmRejectTask(PickupTask task) async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reject this offer?'),
            content: TextField(
              controller: reasonController,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why can’t you take this task?',
                helperText: 'Enter at least 3 characters.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = reasonController.text.trim();
                  if (value.length < 3 || value.length > 1000) {
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                child: const Text('Reject offer'),
              ),
            ],
          );
        },
      );
      if (reason == null || !mounted) {
        return;
      }
      await widget.pickupController.rejectFinalMileTask(task, reason: reason);
      await _closeIfSessionEnded();
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _resolveQr() async {
    final payload = _identifierController.text.trim();
    if (payload.isEmpty) {
      setState(() {
        _resolvedForThisTask = false;
        _resolutionMessage = 'Enter or scan a QR payload first.';
      });
      return;
    }
    final resolution = await widget.pickupController.resolveWaybill(payload);
    if (!mounted) {
      return;
    }
    if (resolution == null) {
      setState(() {
        _resolvedForThisTask = false;
        _resolutionMessage = widget.pickupController.waybillResolutionError ?? 'The QR could not be matched. You may enter the printed Order reference instead.';
      });
      await _closeIfSessionEnded();
      return;
    }

    final task = widget.pickupController.taskWithId(widget.task);
    final matches = _resolutionMatchesTask(resolution, task);
    setState(() {
      _resolvedForThisTask = matches;
      _resolutionMessage = matches
          ? 'The server matched this QR candidate to this task. Confirm pickup only when you have the parcel.'
          : 'This QR belongs to a different or unavailable task. No pickup was changed.';
    });
  }

  bool _resolutionMatchesTask(WaybillResolution resolution, PickupTask task) {
    if (resolution.taskId != null) {
      return resolution.taskId == task.id;
    }
    final taskOrderReference = task.order?.reference;
    return taskOrderReference != null &&
        taskOrderReference == resolution.orderReference;
  }

  Future<void> _submitPickup(PickupTask task) async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty || identifier.length > 128) {
      setState(() {
        _resolvedForThisTask = false;
        _resolutionMessage = 'Enter an identifier up to 128 characters.';
      });
      return;
    }

    if (task.isFirstMile) {
      await widget.pickupController.confirmFirstMilePickup(
        task,
        identifierType: _identifierType,
        identifier: identifier,
      );
    } else {
      await widget.pickupController.submitFinalMilePickup(
        task,
        identifierType: _identifierType,
        identifier: identifier,
      );
    }
    await _closeIfSessionEnded();
  }

  Future<void> _retryPickup(PickupTask task) async {
    if (task.isFirstMile) {
      await widget.pickupController.retryFirstMilePickup(task);
    } else {
      await widget.pickupController.retryFinalMilePickup(task);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _retryRejection(PickupTask task) async {
    await widget.pickupController.retryFinalMileRejection(task);
    await _closeIfSessionEnded();
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
      await widget.pickupController.load();
    }
  }

  Future<void> _closeIfSessionEnded() async {
    if (!mounted || widget.authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _refreshTask(PickupTask task) async {
    if (task.isFinalMile) {
      await widget.pickupController.refreshFinalMileTask(task);
    } else {
      await widget.pickupController.load();
    }
  }

  static bool _canRetryAction(PickupTaskActionStatus status) {
    return status == PickupTaskActionStatus.offline ||
        status == PickupTaskActionStatus.timeout ||
        status == PickupTaskActionStatus.conflict ||
        status == PickupTaskActionStatus.rateLimited ||
        status == PickupTaskActionStatus.failed;
  }
}

class _TaskIdentity extends StatelessWidget {
  const _TaskIdentity({required this.task});

  final PickupTask task;

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
              _taskLegLabel(task),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              task.order?.displayReference ?? 'Order reference unavailable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.waybill?.displayReference ?? 'Waybill reference unavailable',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            _PickupStatusLabel(status: task.rawStatus),
          ],
        ),
      ),
    );
  }
}

class _TaskDetails extends StatelessWidget {
  const _TaskDetails({required this.task});

  final PickupTask task;

  @override
  Widget build(BuildContext context) {
    final pickup = task.pickup;
    final showFullAddress = task.isAccepted || task.hasBeenPickedUp;
    final schedule = task.schedule;
    final rows = <Widget>[
      _DetailRow(
        label: task.isFirstMile ? 'Pickup origin' : 'Pickup location',
        value: pickup?.name ?? _taskLegLabel(task),
      ),
      _DetailRow(
        label: 'Pickup area',
        value: pickup?.areaSummary ?? 'Location unavailable',
      ),
      if (showFullAddress)
        _DetailRow(
          label: 'Authorized pickup address',
          value: pickup?.fullAddress ?? 'Address unavailable',
        ),
      _DetailRow(
        label: 'Destination area',
        value: task.destinationArea?.areaSummary ?? 'Location unavailable',
      ),
      if (task.distanceKm != null)
        _DetailRow(
          label: 'Advisory distance',
          value: '${task.distanceKm!.toStringAsFixed(1)} km',
        ),
      if (task.estimatedDurationMinutes != null)
        _DetailRow(
          label: 'Advisory duration',
          value: '${task.estimatedDurationMinutes} minutes',
        ),
      if (schedule?.startsAt != null)
        _DetailRow(
          label: 'Pickup window',
          value: _formatWindow(schedule) ?? 'Time unavailable',
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pickup details',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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

class _CompletedPickup extends StatelessWidget {
  const _CompletedPickup({
    required this.task,
    required this.controller,
    this.onOpenDelivery,
  });

  final PickupTask task;
  final PickupController controller;
  final VoidCallback? onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstResult = controller.lastFirstMilePickup;
    final finalResult = controller.lastFinalMilePickup;
    final isAwaitingValidation =
        task.isFinalMile &&
        task.status == PickupTaskStatus.deliveryAccepted &&
        controller.actionStatus(task) ==
            PickupTaskActionStatus.awaitingValidation &&
        finalResult?.taskId == task.id;
    final refreshError = controller.taskRefreshError(task);
    final refreshBusy = controller.isTaskRefreshBusy(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isAwaitingValidation
                  ? Icons.hourglass_top_outlined
                  : Icons.check_circle_outline,
              color: scheme.primary,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              isAwaitingValidation
                  ? 'Awaiting Logistics validation'
                  : 'Pickup confirmed',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isAwaitingValidation
                  ? 'Your hub handoff evidence was submitted. The server has not yet recorded physical custody.'
                  : task.isFirstMile
                  ? 'The server recorded physical pickup from the Seller.'
                  : 'The server recorded the current pickup state for this task.',
            ),
            if (firstResult?.taskId == task.id && firstResult?.nextStep != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Next step: ${firstResult!.nextStep}'),
              ),
            if (task.pickedUpAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Recorded ${_formatManilaTimestamp(task.pickedUpAt!)}',
                ),
              ),
            if (refreshError != null) ...[
              const SizedBox(height: 10),
              Text(refreshError, style: TextStyle(color: scheme.error)),
            ],
            if (task.isFinalMile && onOpenDelivery != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onOpenDelivery,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Open delivery work'),
              ),
            ],
            if (task.isFinalMile) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: refreshBusy
                    ? null
                    : () => controller.refreshFinalMileTask(task),
                icon: refreshBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh pickup state'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PickupRouteScreen extends StatefulWidget {
  const PickupRouteScreen({
    required this.pickupController,
    required this.scheduleId,
    this.schedule,
    super.key,
  });

  final PickupController pickupController;
  final String scheduleId;
  final PickupSchedule? schedule;

  @override
  State<PickupRouteScreen> createState() => _PickupRouteScreenState();
}

class _PickupRouteScreenState extends State<PickupRouteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.pickupController.loadRouteManifest(widget.scheduleId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pickupController,
      builder: (context, child) {
        final controller = widget.pickupController;
        final status =
            controller.routeStatuses[widget.scheduleId] ??
            PickupSectionStatus.idle;
        final manifest = controller.routeManifests[widget.scheduleId];
        final error = controller.routeErrors[widget.scheduleId];
        return Scaffold(
          appBar: AppBar(title: const Text('Pickup route order')),
          body: RefreshIndicator(
            onRefresh: () async {
              controller.routeStatuses.remove(widget.scheduleId);
              await controller.loadRouteManifest(widget.scheduleId);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _RouteSummary(schedule: widget.schedule, manifest: manifest),
                const SizedBox(height: 16),
                if (status == PickupSectionStatus.loading && manifest == null)
                  const _PickupLoadingState()
                else if (manifest == null && error != null)
                  _PickupErrorState(
                    message: error,
                    status: status,
                    onRetry: () =>
                        controller.loadRouteManifest(widget.scheduleId),
                    onOpenPolicies: () {},
                    showPolicyAction: false,
                  )
                else if (manifest != null) ...[
                  _RouteStatusBanner(manifest: manifest),
                  const SizedBox(height: 16),
                  if (manifest.stops.isEmpty)
                    const _PickupEmptyState(title: 'route stops')
                  else
                    ..._routeStopWidgets(context, manifest.stops),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.schedule, required this.manifest});

  final PickupSchedule? schedule;
  final PickupRouteManifest? manifest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Authorized stop order',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'This is a schedule-scoped pickup sequence. It is not a Buyer delivery route.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (_formatWindow(schedule) != null) ...[
          const SizedBox(height: 8),
          Text(_formatWindow(schedule)!),
        ],
        if (manifest?.calculatedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Calculated ${_formatManilaTimestamp(manifest!.calculatedAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _RouteStatusBanner extends StatelessWidget {
  const _RouteStatusBanner({required this.manifest});

  final PickupRouteManifest manifest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (message, icon) = switch (manifest.status) {
      RouteManifestStatus.pending => (
        'The route manifest is still being prepared. Pickup details remain available.',
        Icons.hourglass_top_outlined,
      ),
      RouteManifestStatus.ready => (
        'The server provided an ordered route. This screen keeps the stop list available without requiring map tiles.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unavailable => (
        'Route presentation is unavailable. Continue with the authorized stop and address list.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unknown => (
        'The server returned an unsupported route state. Continue with the stop list if present.',
        Icons.info_outline,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

List<Widget> _routeStopWidgets(
  BuildContext context,
  List<PickupRouteStop> stops,
) {
  final ordered = List<PickupRouteStop>.from(stops)
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  return [
    for (final stop in ordered) ...[
      Semantics(
        container: true,
        label: _routeStopSemantics(stop),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 18, child: Text('${stop.sequence + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.isHub ? 'Logistics hub' : 'Pickup stop',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (stop.addressSummary != null) ...[
                        const SizedBox(height: 4),
                        Text(stop.addressSummary!),
                      ],
                      if (stop.orderReferences.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Orders: ${stop.orderReferences.join(', ')}'),
                      ],
                      if (stop.reachable == false) ...[
                        const SizedBox(height: 6),
                        Text(
                          'This stop is unreachable in the current manifest.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  ];
}

String _routeStopSemantics(PickupRouteStop stop) {
  final label = stop.isHub ? 'Logistics hub' : 'Pickup stop';
  return [
    '$label ${stop.sequence + 1}',
    if (stop.addressSummary != null) stop.addressSummary!,
    if (stop.orderReferences.isNotEmpty)
      'Orders ${stop.orderReferences.join(', ')}',
    if (stop.reachable == false) 'unreachable in current manifest',
  ].join('. ');
}

List<List<PickupTask>> _groupTasks(List<PickupTask> tasks) {
  final groups = <String, List<PickupTask>>{};
  for (final task in tasks) {
    final key = task.pickupScheduleId ?? task.schedule?.id ?? task.id;
    groups.putIfAbsent(key, () => <PickupTask>[]).add(task);
  }
  return groups.values.toList(growable: false);
}

bool _isBlockingStatus(PickupSectionStatus status) {
  return status != PickupSectionStatus.idle &&
      status != PickupSectionStatus.loading &&
      status != PickupSectionStatus.loaded &&
      status != PickupSectionStatus.empty;
}

bool _isRecoverableStatus(PickupSectionStatus status) {
  return status == PickupSectionStatus.offline ||
      status == PickupSectionStatus.timeout ||
      status == PickupSectionStatus.failed ||
      status == PickupSectionStatus.rateLimited;
}

String _taskLegLabel(PickupTask task) {
  return task.isFirstMile ? 'Seller pickup' : 'Hub pickup';
}

String _taskStatusLabel(String value) {
  return switch (value) {
    'assigned' => 'Assigned — accept before pickup',
    'accepted' => 'Accepted — ready to verify',
    'picked_up_from_seller' => 'Picked up from Seller',
    'delivery_assigned' => 'Assigned — accept before hub pickup',
    'delivery_accepted' => 'Accepted — ready to verify hub handoff',
    'picked_up_from_hub' => 'Picked up from hub',
    'in_transit' => 'In transit',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'rejected' => 'Offer rejected',
    'cancelled' => 'Cancelled',
    _ => 'Status unavailable',
  };
}

String? _formatWindow(PickupSchedule? schedule) {
  if (schedule == null ||
      (schedule.startsAt == null && schedule.endsAt == null)) {
    return null;
  }
  final start = schedule.startsAt == null
      ? null
      : _formatManilaTimestamp(schedule.startsAt!);
  final end = schedule.endsAt == null
      ? null
      : _formatManilaTimestamp(schedule.endsAt!);
  return [?start, if (end != null) 'to $end', 'Asia/Manila'].join(' ');
}

String _formatManilaTimestamp(DateTime timestamp) {
  final value = timestamp.toUtc().add(const Duration(hours: 8));
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour:$minute $period';
}
