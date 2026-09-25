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
import '../../pickup/domain/pickup_models.dart';
import '../../vehicle/presentation/controllers/vehicle_controller.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_task_preview.dart';
import 'controllers/dashboard_preview_controller.dart';

part 'components/dashboard_body.dart';
part 'components/dashboard_cards.dart';
part 'components/dashboard_status.dart';
part 'components/dashboard_task_previews.dart';
part 'components/dashboard_navigation.dart';

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
    this.dashboardPreviewController,
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
  final DashboardPreviewController? dashboardPreviewController;
  final VehicleController? vehicleController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, _DashboardNavigation {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_clearPreviewsIfAccessLost);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_refreshDashboard(refreshNotifications: false));
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
    if (state == AppLifecycleState.resumed) {
      notificationController?.startPolling();
      if (widget.authController.status == AuthStatus.authenticated) {
        unawaited(_refreshDashboard(refreshNotifications: false));
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      notificationController?.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_clearPreviewsIfAccessLost);
    widget.notificationController?.stopPolling();
    super.dispose();
  }

  void _clearPreviewsIfAccessLost() {
    if (widget.authController.status != AuthStatus.authenticated) {
      widget.dashboardPreviewController?.clear();
    }
  }

  Future<void> _refreshDashboard({bool refreshNotifications = true}) async {
    if (widget.authController.status != AuthStatus.authenticated) return;
    await Future.wait<void>([
      widget.authController.loadDashboard(),
      if (widget.dashboardPreviewController case final controller?)
        controller.refreshAll(),
      if (refreshNotifications && widget.notificationController != null)
        widget.notificationController!.refresh(silent: true),
    ]);
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
            onRefresh: _refreshDashboard,
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
                    previewController: widget.dashboardPreviewController,
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
                      previewController: widget.dashboardPreviewController,
                      profilePhoto: widget.accountController!.profilePhoto,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
