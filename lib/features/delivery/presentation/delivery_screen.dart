import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../../pickup/domain/pickup_models.dart';
import '../domain/delivery_models.dart';
import 'controllers/delivery_controller.dart';

part 'components/delivery_list.dart';
part 'components/delivery_task.dart';
part 'components/delivery_context.dart';
part 'components/delivery_movement.dart';
part 'components/delivery_proof_completion.dart';
part 'components/delivery_status.dart';

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
