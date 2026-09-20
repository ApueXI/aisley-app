import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/notification_models.dart';
import 'controllers/notification_controller.dart';

part 'components/notification_list.dart';
part 'components/notification_detail.dart';
part 'components/notification_status.dart';

typedef NotificationTargetOpener = Future<void> Function(
  CourierNotification notification,
);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    required this.controller,
    this.onOpenTarget,
    this.managePolling = true,
    super.key,
  });

  final NotificationController controller;
  final NotificationTargetOpener? onOpenTarget;
  final bool managePolling;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.managePolling) {
        widget.controller.startPolling();
      }
      unawaited(widget.controller.refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.managePolling) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      widget.controller.startPolling();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.controller.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.managePolling) {
      widget.controller.stopPolling();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            IconButton(
              onPressed:
                  widget.controller.isLoading ||
                      !widget.controller.canRetryRateLimit
                  ? null
                  : widget.controller.refresh,
              tooltip: 'Refresh notifications',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: _NotificationListBody(
            controller: widget.controller,
            onOpenNotification: _openNotification,
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(CourierNotification notification) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailScreen(
          controller: widget.controller,
          notification: notification,
          onOpenTarget: widget.onOpenTarget,
        ),
      ),
    );
  }
}
