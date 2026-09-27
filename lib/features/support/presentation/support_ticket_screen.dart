import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/support_ticket_models.dart';
import 'controllers/support_ticket_controller.dart';

part 'components/support_ticket_list.dart';
part 'components/support_ticket_create.dart';
part 'components/support_ticket_detail.dart';
part 'components/support_ticket_status.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({
    required this.controller,
    required this.authController,
    super.key,
  });

  final SupportTicketController controller;
  final AuthController authController;

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen>
    with WidgetsBindingObserver {
  bool _childRouteOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_leaveOnSessionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.startListPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_childRouteOpen) widget.controller.startListPolling();
    } else {
      widget.controller.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_leaveOnSessionChange);
    widget.controller.stopPolling();
    super.dispose();
  }

  void _leaveOnSessionChange() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _createTicket() async {
    _childRouteOpen = true;
    widget.controller.stopPolling();
    final ticket = await Navigator.of(context).push<SupportTicketSummary>(
      MaterialPageRoute<SupportTicketSummary>(
        builder: (_) => SupportTicketCreateScreen(
          controller: widget.controller,
          authController: widget.authController,
        ),
      ),
    );
    _childRouteOpen = false;
    if (!mounted || widget.authController.status != AuthStatus.authenticated) {
      return;
    }
    if (ticket != null) await _openTicket(ticket);
    unawaited(widget.controller.refreshList(silent: true));
    widget.controller.startListPolling(refreshImmediately: false);
  }

  Future<void> _openTicket(SupportTicketSummary ticket) async {
    _childRouteOpen = true;
    widget.controller.stopPolling();
    final unavailableMessage = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SupportTicketDetailScreen(
          controller: widget.controller,
          authController: widget.authController,
          ticket: ticket,
        ),
      ),
    );
    _childRouteOpen = false;
    if (!mounted || widget.authController.status != AuthStatus.authenticated) {
      return;
    }
    widget.controller.closeDetail();
    if (unavailableMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(unavailableMessage)));
    }
    widget.controller.startListPolling();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.authController]),
      builder: (context, child) {
        if (widget.authController.status != AuthStatus.authenticated) {
          return const Scaffold(body: Center(child: Text('Session ended.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Support tickets'),
            actions: [
              IconButton(
                onPressed:
                    widget.controller.listStatus ==
                            SupportTicketLoadStatus.loading ||
                        !widget.controller.canRetry
                    ? null
                    : widget.controller.refreshList,
                tooltip: 'Refresh support tickets',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: widget.controller.refreshList,
            child: _SupportTicketList(
              controller: widget.controller,
              onCreate: _createTicket,
              onOpen: _openTicket,
            ),
          ),
        );
      },
    );
  }
}
