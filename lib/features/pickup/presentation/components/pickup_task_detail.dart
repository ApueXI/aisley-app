part of '../pickup_screen.dart';

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

  PickupController get _pickupController => widget.pickupController;

  AuthController get _authController => widget.authController;

  PolicyController? get _policyController => widget.policyController;

  VoidCallback? get _onOpenDelivery => widget.onOpenDelivery;

  BuildContext get _pickupContext => context;

  bool get _pickupMounted => mounted;

  void _pickupSetState(VoidCallback callback) => setState(callback);

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
            onRefresh: widget.pickupController.load,
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
        controller: _pickupController,
        onOpenDelivery: _onOpenDelivery,
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
}
