import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/final_mile_batch_models.dart';
import 'controllers/final_mile_batch_controller.dart';

part 'components/final_mile_batch_list.dart';
part 'components/final_mile_batch_detail.dart';
part 'components/final_mile_batch_acceptance.dart';
part 'components/final_mile_batch_status.dart';

class FinalMileBatchScreen extends StatefulWidget {
  const FinalMileBatchScreen({
    required this.authController,
    required this.batchController,
    this.policyController,
    super.key,
  });

  final AuthController authController;
  final FinalMileBatchController batchController;
  final PolicyController? policyController;

  @override
  State<FinalMileBatchScreen> createState() => _FinalMileBatchScreenState();
}

class _FinalMileBatchScreenState extends State<FinalMileBatchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.batchController.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.batchController,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Final-mile batches')),
          body: RefreshIndicator(
            onRefresh: widget.batchController.load,
            child: _FinalMileBatchList(
              controller: widget.batchController,
              onOpenBatch: _openBatch,
              onOpenPolicies: _openPolicies,
              canOpenPolicies: widget.policyController != null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBatch(FinalMileBatch batch) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinalMileBatchDetailScreen(
          authController: widget.authController,
          batchController: widget.batchController,
          scheduleId: batch.id,
          policyController: widget.policyController,
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
    if (mounted) await widget.batchController.load();
  }
}

String _batchStatusLabel(FinalMileBatchStatus status) {
  return switch (status) {
    FinalMileBatchStatus.offered => 'Awaiting acceptance',
    FinalMileBatchStatus.accepted => 'Accepted',
    FinalMileBatchStatus.inProgress => 'In progress',
  };
}

String _formatBatchSchedule(DateTime timestamp) {
  final value = timestamp.toUtc().add(const Duration(hours: 8));
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour:$minute $period';
}
