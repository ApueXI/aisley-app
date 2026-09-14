import 'package:flutter/material.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../../pickup/domain/pickup_models.dart';
import '../domain/delivery_models.dart';
import 'delivery_controller.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({
    required this.authController,
    required this.deliveryController,
    this.policyController,
    this.onOpenPickup,
    super.key,
  });

  final AuthController authController;
  final DeliveryController deliveryController;
  final PolicyController? policyController;
  final VoidCallback? onOpenPickup;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.deliveryController.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.deliveryController,
      builder: (context, child) {
        final controller = widget.deliveryController;
        return Scaffold(
          appBar: AppBar(title: const Text('Delivery work')),
          body: RefreshIndicator(
            onRefresh: controller.load,
            child: _DeliveryListBody(
              controller: controller,
              onOpenTask: _openTask,
              onRetry: controller.load,
              onOpenPolicies: _openPolicies,
              showPolicyAction: widget.policyController != null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTask(PickupTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryTaskScreen(
          authController: widget.authController,
          deliveryController: widget.deliveryController,
          policyController: widget.policyController,
          task: task,
          onOpenPickup: widget.onOpenPickup,
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
      await widget.deliveryController.load();
    }
  }
}

class _DeliveryListBody extends StatelessWidget {
  const _DeliveryListBody({
    required this.controller,
    required this.onOpenTask,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final DeliveryController controller;
  final ValueChanged<PickupTask> onOpenTask;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final status = controller.loadStatus;
    final tasks = controller.tasks;
    final isBlocking =
        status != DeliveryLoadStatus.idle &&
        status != DeliveryLoadStatus.loading &&
        status != DeliveryLoadStatus.loaded &&
        status != DeliveryLoadStatus.empty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Final-mile deliveries',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Move only the delivery assigned to you. The server confirms every state and handoff.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        if ((status == DeliveryLoadStatus.idle ||
                status == DeliveryLoadStatus.loading) &&
            tasks.isEmpty)
          const _DeliveryLoadingCard()
        else if (isBlocking && tasks.isEmpty)
          _DeliveryErrorCard(
            message: controller.errorMessage ?? 'Delivery work is unavailable.',
            status: status,
            onRetry: onRetry,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: showPolicyAction,
          )
        else if (status == DeliveryLoadStatus.empty || tasks.isEmpty)
          const _DeliveryEmptyCard()
        else ...[
          for (final task in tasks) ...[
            _DeliveryTaskCard(task: task, onTap: () => onOpenTask(task)),
            const SizedBox(height: 10),
          ],
          if (controller.errorMessage != null)
            _DeliveryInlineError(
              message: controller.errorMessage!,
              onRetry: onRetry,
            ),
        ],
      ],
    );
  }
}

class _DeliveryTaskCard extends StatelessWidget {
  const _DeliveryTaskCard({required this.task, required this.onTap});

  final PickupTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destination = task.destinationArea?.areaSummary;
    final order = task.order?.reference ?? 'Order reference unavailable';
    final details = <String>[
      'Final-mile delivery',
      _deliveryStatusLabel(task.rawStatus),
      'Order $order',
      if (destination != null && destination != 'Location unavailable')
        'Destination $destination',
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
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
                        destination == null ||
                                destination == 'Location unavailable'
                            ? 'Destination area unavailable'
                            : 'To $destination',
                      ),
                      const SizedBox(height: 10),
                      _DeliveryStatusPill(
                        label: _deliveryStatusLabel(task.rawStatus),
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

class DeliveryTaskScreen extends StatefulWidget {
  const DeliveryTaskScreen({
    required this.authController,
    required this.deliveryController,
    required this.task,
    this.policyController,
    this.onOpenPickup,
    super.key,
  });

  final AuthController authController;
  final DeliveryController deliveryController;
  final PickupTask task;
  final PolicyController? policyController;
  final VoidCallback? onOpenPickup;

  @override
  State<DeliveryTaskScreen> createState() => _DeliveryTaskScreenState();
}

class _DeliveryTaskScreenState extends State<DeliveryTaskScreen> {
  final _proofIdentifierController = TextEditingController();
  // Manual Order-reference entry is the supported fallback when a camera
  // scanner is unavailable. QR remains an explicit opt-in mode so typing a
  // public Order reference cannot accidentally be submitted as a QR payload.
  String _proofIdentifierType = 'order_id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.deliveryController.loadDetails(widget.task);
      }
    });
  }

  @override
  void dispose() {
    _proofIdentifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.deliveryController,
      builder: (context, child) {
        final controller = widget.deliveryController;
        final task = controller.taskById(widget.task.id) ?? widget.task;
        final deliveryContext = controller.contexts[task.id];
        return Scaffold(
          appBar: AppBar(title: const Text('Deliver order')),
          body: RefreshIndicator(
            onRefresh: () => controller.loadDetails(task),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _DeliveryIdentity(task: task),
                const SizedBox(height: 16),
                _DeliveryContextCard(
                  contextData: deliveryContext,
                  status:
                      controller.contextStatuses[task.id] ??
                      DeliveryLoadStatus.idle,
                  error: controller.contextErrors[task.id],
                  onRetry: () => controller.loadDetails(task),
                ),
                const SizedBox(height: 16),
                _buildAction(context, task, deliveryContext),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAction(
    BuildContext context,
    PickupTask task,
    DeliveryContext? deliveryContext,
  ) {
    if (task.status == PickupTaskStatus.delivered) {
      return _CompletedDeliveryCard();
    }
    if (task.status == PickupTaskStatus.deliveryAssigned ||
        task.status == PickupTaskStatus.deliveryAccepted) {
      return _BeforeHubPickupCard(onOpenPickup: widget.onOpenPickup);
    }
    if (task.status == PickupTaskStatus.pickedUpFromHub ||
        task.status == PickupTaskStatus.inTransit) {
      return _MovementCard(
        task: task,
        controller: widget.deliveryController,
        onOpenPolicies: _openPolicies,
        showPolicyAction: widget.policyController != null,
      );
    }
    if (task.isFinalMile && task.status == PickupTaskStatus.outForDelivery) {
      return _ProofAndCompletionCard(
        task: task,
        controller: widget.deliveryController,
        identifierController: _proofIdentifierController,
        identifierType: _proofIdentifierType,
        onIdentifierTypeChanged: (value) {
          setState(() {
            _proofIdentifierType = value;
          });
        },
        onOpenPolicies: _openPolicies,
        showPolicyAction: widget.policyController != null,
      );
    }
    return const _DeliveryUnavailableActionCard();
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
      await widget.deliveryController.loadDetails(widget.task);
    }
  }
}

class _DeliveryIdentity extends StatelessWidget {
  const _DeliveryIdentity({required this.task});

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
              'Final-mile delivery',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              task.order?.reference ?? 'Order reference unavailable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.waybill?.reference ?? 'Waybill reference unavailable',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            _DeliveryStatusPill(label: _deliveryStatusLabel(task.rawStatus)),
          ],
        ),
      ),
    );
  }
}

class _DeliveryContextCard extends StatelessWidget {
  const _DeliveryContextCard({
    required this.contextData,
    required this.status,
    required this.error,
    required this.onRetry,
  });

  final DeliveryContext? contextData;
  final DeliveryLoadStatus status;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if ((status == DeliveryLoadStatus.idle ||
            status == DeliveryLoadStatus.loading) &&
        contextData == null) {
      return const _DeliveryLoadingCard();
    }
    if (contextData == null) {
      return _DeliveryErrorCard(
        message: error ?? 'Delivery context is unavailable.',
        status: status,
        onRetry: onRetry,
        onOpenPolicies: () {},
        showPolicyAction: false,
      );
    }
    final data = contextData!;
    final destination = data.destination;
    final hub = data.hub;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery details',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _DeliveryDetailRow(
              label: 'Pickup hub',
              value: hub?.fullAddress ?? hub?.areaSummary ?? 'Hub unavailable',
            ),
            _DeliveryDetailRow(
              label: 'Destination',
              value:
                  destination?.fullAddress ??
                  destination?.areaSummary ??
                  'Destination unavailable',
            ),
            if (data.recipientName != null)
              _DeliveryDetailRow(
                label: 'Recipient',
                value: data.recipientName!,
              ),
            if (data.recipientPhone != null)
              _DeliveryDetailRow(
                label: 'Contact number',
                value: data.recipientPhone!,
              ),
            if (data.deliveryInstructions != null)
              _DeliveryDetailRow(
                label: 'Delivery instructions',
                value: data.deliveryInstructions!,
              ),
            const SizedBox(height: 6),
            _RouteMetrics(contextData: data),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteMetrics extends StatelessWidget {
  const _RouteMetrics({required this.contextData});

  final DeliveryContext contextData;

  @override
  Widget build(BuildContext context) {
    final metrics = <String>[
      if (contextData.distanceKm != null)
        'Advisory distance: ${contextData.distanceKm!.toStringAsFixed(1)} km',
      if (contextData.estimatedDurationMinutes != null)
        'Advisory duration: ${contextData.estimatedDurationMinutes} minutes',
    ];
    final routeStatus = contextData.routeStatus;
    final hasMetrics = metrics.isNotEmpty;
    final calculatedAt = contextData.calculatedAt;
    return Semantics(
      label: hasMetrics
          ? [
              ...metrics,
              if (calculatedAt != null)
                'calculated ${_formatTimestamp(calculatedAt)}',
            ].join('. ')
          : 'Route metrics unavailable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMetrics) ...[
            for (final metric in metrics) Text(metric),
            if (calculatedAt != null)
              Text(
                'Calculated ${_formatTimestamp(calculatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ] else
            Text(
              routeStatus == 'stale'
                  ? 'Route metrics are stale and advisory. Refresh before relying on them.'
                  : 'Route metrics unavailable. Continue with the authorized destination details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

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
                      : controller.hasPendingMovement(task)
                      ? () => controller.retryMovement(task)
                      : controller.load,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    controller.hasPendingMovement(task)
                        ? 'Retry same movement attempt'
                        : 'Refresh task',
                  ),
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

class _ProofAndCompletionCard extends StatelessWidget {
  const _ProofAndCompletionCard({
    required this.task,
    required this.controller,
    required this.identifierController,
    required this.identifierType,
    required this.onIdentifierTypeChanged,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final PickupTask task;
  final DeliveryController controller;
  final TextEditingController identifierController;
  final String identifierType;
  final ValueChanged<String> onIdentifierTypeChanged;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final actionStatus = controller.actionStatus(task);
    final actionError = controller.actionError(task);
    final completion = controller.completions[task.id];
    final proof = controller.proofs[task.id];
    final evidenceId = proof?.proofId ?? completion?.evidenceId;
    final evidenceStatus = proof?.evidenceStatus ?? completion?.evidenceStatus;
    final proofRecorded = proof != null || completion?.evidenceId != null;
    final proofRejected = evidenceStatus == 'rejected';
    final busy = controller.isActionBusy(task);
    final proofPending =
        actionStatus == DeliveryActionStatus.proofAwaitingValidation ||
        evidenceStatus == 'awaiting_validation';
    final completionPending = controller.isCompletionPending(task);
    final actionBlocked = !controller.canStartAction(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proof and completion',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'The current P0 proof method is QR or printed Order reference. Photo and signature proof are not enabled.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'qr',
                  label: Text('Delivery QR'),
                  icon: Icon(Icons.qr_code_2),
                ),
                ButtonSegment<String>(
                  value: 'order_id',
                  label: Text('Order reference'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: <String>{identifierType},
              onSelectionChanged: busy || actionBlocked
                  ? null
                  : (values) {
                      if (values.isNotEmpty) {
                        onIdentifierTypeChanged(values.first);
                      }
                    },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: identifierController,
              enabled: !busy && !proofPending && !actionBlocked,
              maxLength: 128,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: identifierType == 'qr'
                    ? 'Raw delivery QR payload'
                    : 'Public Order reference',
                helperText: identifierType == 'qr'
                    ? 'Submit the QR payload exactly as scanned; the server verifies it for this task.'
                    : 'Enter the public Order reference shown above. Database IDs and waybill references are not accepted.',
                border: const OutlineInputBorder(),
              ),
            ),
            if (actionError != null) ...[
              const SizedBox(height: 10),
              Text(
                actionError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (actionStatus == DeliveryActionStatus.consentRequired &&
                  showPolicyAction)
                TextButton.icon(
                  onPressed: onOpenPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus == DeliveryActionStatus.conflict)
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.loadDetails(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh task before retrying'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus != DeliveryActionStatus.conflict &&
                  controller.hasPendingProof(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryProof(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same proof attempt'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus != DeliveryActionStatus.conflict &&
                  controller.hasPendingCompletion(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryCompletion(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same completion attempt'),
                ),
            ],
            if (proofPending || (proofRecorded && !proofRejected)) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: evidenceStatus == 'validated'
                    ? 'Proof validated by Logistics'
                    : 'Proof awaiting Logistics validation',
                child: Text(
                  evidenceStatus == 'validated'
                      ? 'Proof validated by Logistics. This does not mark the delivery complete.'
                      : 'Awaiting Logistics validation. This proof submission does not mean the delivery is complete.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ] else ...[
              if (proofRejected)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Logistics rejected the previous proof. Correct the identifier and submit a new proof attempt.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: busy || actionBlocked
                      ? null
                      : () => controller.submitProof(
                          task,
                          identifierType: identifierType,
                          identifier: identifierController.text,
                        ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Submit proof'),
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Complete delivery',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (controller.completionErrors[task.id] != null) ...[
              Text(
                controller.completionErrors[task.id]!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (completionPending)
              const _AwaitingCompletionText()
            else if (completion?.isDelivered == true)
              const _DeliveredStatusText()
            else if (evidenceId == null)
              const Text(
                'Submit the required proof before sending completion intent.',
              )
            else if (proofRejected)
              const Text(
                'Correct and resubmit the proof after Logistics rejected the previous evidence.',
              )
            else ...[
              Text(
                evidenceStatus == 'awaiting_validation'
                    ? 'Proof is awaiting Logistics validation. Submit completion intent so Logistics can continue validation.'
                    : 'The server returned proof for this task. Submit completion intent to finish the Courier handoff.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy || actionBlocked
                    ? null
                    : () => _confirmCompletion(context, evidenceId),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: const Text('Submit completion'),
              ),
            ],
            OutlinedButton.icon(
              onPressed:
                  busy ||
                      !controller.canRetryRateLimit ||
                      controller.completionStatuses[task.id] ==
                          DeliveryLoadStatus.loading
                  ? null
                  : () => controller.loadCompletion(task),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh completion status'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCompletion(
    BuildContext context,
    String evidenceId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit completion intent?'),
        content: const Text(
          'This sends the server the completion intent for this delivery. It will remain pending until Logistics validates the proof.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit intent'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.submitCompletion(task, evidenceId: evidenceId);
    }
  }
}

class _BeforeHubPickupCard extends StatelessWidget {
  const _BeforeHubPickupCard({required this.onOpenPickup});

  final VoidCallback? onOpenPickup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hub pickup is next',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Accept the final-mile offer and submit hub handoff evidence in Pickup orders before starting delivery.',
            ),
            if (onOpenPickup != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onOpenPickup,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Open pickup orders'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedDeliveryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Semantics(
          liveRegion: true,
          label: 'Delivery completed',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline),
              SizedBox(height: 10),
              Text('Delivery completed'),
              SizedBox(height: 6),
              Text('The server marked this final-mile task delivered.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveredStatusText extends StatelessWidget {
  const _DeliveredStatusText();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Delivery completed by the server',
      child: Text('Delivery completed by the server.'),
    );
  }
}

class _AwaitingCompletionText extends StatelessWidget {
  const _AwaitingCompletionText();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Awaiting Logistics validation for completion',
      child: Text(
        'Completion intent accepted by the server. Awaiting Logistics validation. Refresh to see whether delivery was finalized.',
      ),
    );
  }
}

class _DeliveryDetailRow extends StatelessWidget {
  const _DeliveryDetailRow({required this.label, required this.value});

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

class _DeliveryStatusPill extends StatelessWidget {
  const _DeliveryStatusPill({required this.label});

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

class _DeliveryLoadingCard extends StatelessWidget {
  const _DeliveryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading delivery work',
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _DeliveryEmptyCard extends StatelessWidget {
  const _DeliveryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No final-mile deliveries are assigned right now.'),
      ),
    );
  }
}

class _DeliveryUnavailableActionCard extends StatelessWidget {
  const _DeliveryUnavailableActionCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'No delivery action is available for this server status. Refresh to check for an updated task state.',
        ),
      ),
    );
  }
}

class _DeliveryErrorCard extends StatelessWidget {
  const _DeliveryErrorCard({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final String message;
  final DeliveryLoadStatus status;
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
                if (_canRetryLoad(status))
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (status == DeliveryLoadStatus.consentRequired &&
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

class _DeliveryInlineError extends StatelessWidget {
  const _DeliveryInlineError({required this.message, required this.onRetry});

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

bool _canRetryLoad(DeliveryLoadStatus status) {
  return status == DeliveryLoadStatus.offline ||
      status == DeliveryLoadStatus.timeout ||
      status == DeliveryLoadStatus.failed ||
      status == DeliveryLoadStatus.rateLimited;
}

bool _canRetry(DeliveryActionStatus status) {
  return status == DeliveryActionStatus.offline ||
      status == DeliveryActionStatus.timeout ||
      status == DeliveryActionStatus.conflict ||
      status == DeliveryActionStatus.rateLimited ||
      status == DeliveryActionStatus.failed;
}

String _deliveryStatusLabel(String status) {
  return switch (status) {
    'delivery_assigned' => 'Assigned — accept before hub pickup',
    'delivery_accepted' => 'Accepted — ready for hub pickup',
    'picked_up_from_hub' => 'Picked up from hub',
    'in_transit' => 'In transit',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'rejected' => 'Offer rejected',
    _ => 'Status unavailable',
  };
}

String _formatTimestamp(DateTime timestamp) {
  final value = timestamp.toUtc().add(const Duration(hours: 8));
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute $period (Asia/Manila)';
}
