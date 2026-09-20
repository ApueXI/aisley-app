part of '../delivery_screen.dart';

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
  String _proofIdentifierType = 'qr';

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
        onScan: _openProofScanner,
        onOpenPolicies: _openPolicies,
        showPolicyAction: widget.policyController != null,
      );
    }
    return const _DeliveryUnavailableActionCard();
  }

  Future<void> _openProofScanner() async {
    final candidate = await Navigator.of(context).push<BarcodeScanCandidate>(
      MaterialPageRoute<BarcodeScanCandidate>(
        builder: (_) => const BarcodeScannerScreen(title: 'Scan delivery code'),
      ),
    );
    if (candidate == null || !mounted) {
      return;
    }
    _proofIdentifierController.text = candidate.value;
    setState(() {
      _proofIdentifierType = candidate.identifierType;
    });
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
