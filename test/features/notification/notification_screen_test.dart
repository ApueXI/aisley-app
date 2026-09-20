import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/notification/presentation/notification_screen.dart';

void main() {
  testWidgets('starts only one initial refresh when it owns polling', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(home: NotificationScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(repository.unreadCountCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows unread notifications and explicit mark-read action', (
    tester,
  ) async {
    final controller = NotificationController(
      notificationRepository: _FakeNotificationRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(
          controller: controller,
          managePolling: false,
          onOpenTarget: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courier inbox'), findsOneWidget);
    expect(find.text('Delivery offered'), findsOneWidget);
    expect(find.text('1 unread notification'), findsOneWidget);

    await tester.tap(find.text('Delivery offered'));
    await tester.pumpAndSettle();

    expect(find.text('Notification details'), findsOneWidget);
    expect(find.text('Mark as read'), findsOneWidget);
    expect(find.text('Open related work'), findsOneWidget);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();

    expect(find.text('Already read'), findsOneWidget);
    expect(controller.notificationById('notification-1')?.isRead, isTrue);
  });

  testWidgets(
    'shows stale data instead of converting a failed refresh to empty',
    (tester) async {
      final repository = _FakeNotificationRepository();
      final controller = NotificationController(
        notificationRepository: repository,
      );
      await controller.refresh();
      repository.failList = true;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationScreen(
            controller: controller,
            managePolling: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery offered'), findsOneWidget);
      expect(
        find.textContaining('Showing stale notifications.'),
        findsOneWidget,
      );
      expect(find.text('No notifications yet'), findsNothing);
    },
  );

  testWidgets('distinguishes a successful empty inbox from an error', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository()..empty = true;
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(controller: controller, managePolling: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('Notifications are unavailable.'), findsNothing);
  });

  testWidgets('shows forbidden notification access without an empty state', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository()
      ..listError = const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'forbidden',
      );
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(controller: controller, managePolling: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your Courier account is not currently allowed to view notifications.',
      ),
      findsOneWidget,
    );
    expect(find.text('No notifications yet'), findsNothing);
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  bool failList = false;
  bool empty = false;
  ApiException? listError;
  int listCalls = 0;
  int unreadCountCalls = 0;

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    if (listError != null) {
      throw listError!;
    }
    if (failList) {
      throw const ApiException.network('offline');
    }
    if (empty) {
      return const CourierNotificationPage(items: <CourierNotification>[]);
    }
    return CourierNotificationPage(
      items: <CourierNotification>[_notification],
      generatedAt: null,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    unreadCountCalls++;
    return 1;
  }

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async =>
      _notification;

  @override
  Future<CourierNotification> markRead(String notificationId) async =>
      _notification.copyWith(readAt: DateTime.utc(2026, 9, 20, 2, 1));
}

final _notification = CourierNotification(
  id: 'notification-1',
  type: 'courier-task.final-mile-offered',
  title: 'Delivery offered',
  summary: 'A delivery request is available.',
  createdAt: DateTime.utc(2026, 9, 20, 2),
  resourceType: 'delivery_task',
  resourceId: 'task-1',
  destination: '/delivery-tasks/task-1',
);
