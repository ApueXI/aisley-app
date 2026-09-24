import 'dart:async';

import 'package:flutter/material.dart';

import '../../account/domain/account_models.dart';
import '../../account/presentation/controllers/account_controller.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../chat/presentation/chat_inbox_screen.dart';
import '../../chat/presentation/controllers/chat_controller.dart';
import '../../delivery/presentation/controllers/delivery_controller.dart';
import '../../delivery/presentation/delivery_screen.dart';
import '../../history/presentation/controllers/history_controller.dart';
import '../../history/presentation/history_screen.dart';
import '../../notification/domain/notification_models.dart';
import '../../notification/presentation/controllers/notification_controller.dart';
import '../../notification/presentation/notification_screen.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../pickup/presentation/controllers/pickup_controller.dart';
import '../../pickup/presentation/pickup_screen.dart';
import '../../vehicle/presentation/controllers/vehicle_controller.dart';
import '../domain/dashboard_models.dart';

part 'components/dashboard_body.dart';
part 'components/dashboard_cards.dart';
part 'components/dashboard_status.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.authController,
    this.accountController,
    this.policyController,
    this.pickupController,
    this.deliveryController,
    this.historyController,
    this.notificationController,
    this.chatController,
    this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final AccountController? accountController;
  final PolicyController? policyController;
  final PickupController? pickupController;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final NotificationController? notificationController;
  final ChatController? chatController;
  final VehicleController? vehicleController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.authController.loadDashboard();
        widget.notificationController?.startPolling();
        final accountController = widget.accountController;
        if (accountController != null && accountController.account == null) {
          unawaited(accountController.loadAccount());
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notificationController = widget.notificationController;
    if (notificationController == null) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      notificationController.startPolling();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      notificationController.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationController?.stopPolling();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to view your Courier dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    final didSignOut = await widget.authController.signOut();
    if (!mounted || didSignOut) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign out could not be completed. Your session remains active.',
        ),
      ),
    );
  }

  Future<void> _openAccount() async {
    final accountController = widget.accountController;
    if (accountController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountScreen(
          authController: widget.authController,
          accountController: accountController,
          policyController: widget.policyController,
          vehicleController: widget.vehicleController,
        ),
      ),
    );
  }

  Future<void> _openPickups() async {
    final pickupController = widget.pickupController;
    if (pickupController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickupScreen(
          authController: widget.authController,
          pickupController: pickupController,
          policyController: widget.policyController,
          onOpenDelivery: _openDeliveries,
          chatController: widget.chatController,
        ),
      ),
    );
  }

  Future<void> _openDeliveries() async {
    final deliveryController = widget.deliveryController;
    if (deliveryController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryScreen(
          authController: widget.authController,
          deliveryController: deliveryController,
          policyController: widget.policyController,
          onOpenPickup: _openPickups,
          chatController: widget.chatController,
        ),
      ),
    );
  }

  Future<void> _openHistory() async {
    final historyController = widget.historyController;
    if (historyController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          authController: widget.authController,
          historyController: historyController,
          policyController: widget.policyController,
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    final notificationController = widget.notificationController;
    if (notificationController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationScreen(
          controller: notificationController,
          managePolling: false,
          onOpenTarget: _openNotificationTarget,
        ),
      ),
    );
    if (mounted) {
      notificationController.startPolling();
    }
  }

  Future<void> _openNotificationTarget(CourierNotification notification) async {
    switch (notification.resourceType) {
      case 'pickup_schedule':
        await _openPickups();
      case 'delivery_task':
      case 'final_mile_task':
        await _openDeliveries();
      default:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The related work type is not available in this app yet.',
              ),
            ),
          );
        }
    }
  }

  Future<void> _openMessages() async {
    final chatController = widget.chatController;
    if (chatController == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatInboxScreen(
          controller: chatController,
          authController: widget.authController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, child) {
        final courier = widget.authController.courier;
        if (courier == null) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Courier dashboard'),
            actions: [
              if (widget.pickupController != null ||
                  widget.deliveryController != null ||
                  widget.historyController != null)
                PopupMenuButton<String>(
                  tooltip: 'Courier work',
                  icon: const Icon(Icons.local_shipping_outlined),
                  onSelected: (value) {
                    switch (value) {
                      case 'pickup':
                        _openPickups();
                      case 'delivery':
                        _openDeliveries();
                      case 'history':
                        _openHistory();
                    }
                  },
                  itemBuilder: (context) => [
                    if (widget.pickupController != null)
                      const PopupMenuItem<String>(
                        value: 'pickup',
                        child: Text('Pickup orders'),
                      ),
                    if (widget.deliveryController != null)
                      const PopupMenuItem<String>(
                        value: 'delivery',
                        child: Text('Delivery work'),
                      ),
                    if (widget.historyController != null)
                      const PopupMenuItem<String>(
                        value: 'history',
                        child: Text('Delivery history'),
                      ),
                  ],
                ),
              if (widget.notificationController != null)
                AnimatedBuilder(
                  animation: widget.notificationController!,
                  builder: (context, child) {
                    final count = widget.notificationController!.unreadCount;
                    final label = count == null
                        ? 'Notifications'
                        : '$count unread notification${count == 1 ? '' : 's'}';
                    return Semantics(
                      button: true,
                      label: label,
                      child: IconButton(
                        onPressed: _openNotifications,
                        tooltip: 'Notifications',
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded),
                            if (count != null && count > 0)
                              Positioned(
                                right: -5,
                                top: -5,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onError,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (widget.accountController != null)
                IconButton(
                  onPressed: _openAccount,
                  tooltip: 'Account settings',
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
              IconButton(
                onPressed: widget.authController.isSigningOut
                    ? null
                    : _confirmSignOut,
                tooltip: 'Sign out',
                icon: widget.authController.isSigningOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: widget.authController.loadDashboard,
            child: widget.accountController == null
                ? _DashboardBody(
                    authController: widget.authController,
                    onSignOut: _confirmSignOut,
                    pickupController: widget.pickupController,
                    onOpenPickups: _openPickups,
                    deliveryController: widget.deliveryController,
                    historyController: widget.historyController,
                    onOpenDeliveries: _openDeliveries,
                    onOpenHistory: _openHistory,
                    onOpenNotifications: widget.notificationController == null
                        ? null
                        : _openNotifications,
                    onOpenMessages: widget.chatController == null
                        ? null
                        : _openMessages,
                  )
                : AnimatedBuilder(
                    animation: widget.accountController!,
                    builder: (context, child) => _DashboardBody(
                      authController: widget.authController,
                      onSignOut: _confirmSignOut,
                      pickupController: widget.pickupController,
                      onOpenPickups: _openPickups,
                      deliveryController: widget.deliveryController,
                      historyController: widget.historyController,
                      onOpenDeliveries: _openDeliveries,
                      onOpenHistory: _openHistory,
                      onOpenNotifications: widget.notificationController == null
                          ? null
                          : _openNotifications,
                      onOpenMessages: widget.chatController == null
                          ? null
                          : _openMessages,
                      profilePhoto: widget.accountController!.profilePhoto,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
