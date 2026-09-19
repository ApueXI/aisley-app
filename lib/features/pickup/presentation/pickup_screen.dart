import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/pickup_models.dart';
import 'controllers/pickup_controller.dart';

part 'components/pickup_list.dart';
part 'components/pickup_task_detail.dart';
part 'components/pickup_task_actions.dart';
part 'components/pickup_task_interactions.dart';
part 'components/pickup_task_info.dart';
part 'components/pickup_route.dart';
part 'components/pickup_status.dart';

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
