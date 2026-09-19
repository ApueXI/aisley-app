import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/history_models.dart';
import 'controllers/history_controller.dart';

part 'components/history_list.dart';
part 'components/history_detail.dart';
part 'components/history_status.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.authController,
    required this.historyController,
    this.policyController,
    super.key,
  });

  final AuthController authController;
  final HistoryController historyController;
  final PolicyController? policyController;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.historyController.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.historyController,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Delivery history')),
          body: RefreshIndicator(
            onRefresh: widget.historyController.load,
            child: _HistoryListBody(
              controller: widget.historyController,
              onOpenItem: _openItem,
              onRetry: widget.historyController.retry,
              onOpenPolicies: _openPolicies,
              showPolicyAction: widget.policyController != null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openItem(DeliveryHistoryItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryDetailScreen(
          authController: widget.authController,
          historyController: widget.historyController,
          item: item,
          policyController: widget.policyController,
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
      await widget.historyController.load();
    }
  }
}
