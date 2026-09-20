import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';

void main() {
  test('loads the inbox and unread count independently', () async {
    final repository = _FakeNotificationRepository();
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await controller.refresh();

    expect(controller.listStatus, NotificationLoadStatus.loaded);
    expect(controller.countStatus, NotificationLoadStatus.loaded);
    expect(controller.items.single.id, 'notification-1');
    expect(controller.unreadCount, 1);
  });

  test('keeps a stale inbox when a refresh becomes unavailable', () async {
    final repository = _FakeNotificationRepository();
    final controller = NotificationController(
      notificationRepository: repository,
    );
    await controller.refresh();

    repository.listError = const ApiException.network(
      'offline',
      networkFailure: ApiNetworkFailure.offline,
    );
    await controller.refresh();

    expect(controller.items.single.id, 'notification-1');
    expect(controller.hasStaleItems, isTrue);
    expect(controller.listErrorMessage, contains('offline'));
  });

  test('marks read through the server and refreshes the count', () async {
    final repository = _FakeNotificationRepository();
    final controller = NotificationController(
      notificationRepository: repository,
    );
    await controller.refresh();

    final marked = await controller.markRead('notification-1');
    await Future<void>.delayed(Duration.zero);

    expect(marked, isTrue);
    expect(repository.markedIds, <String>['notification-1']);
    expect(controller.notificationById('notification-1')?.isRead, isTrue);
    expect(
      controller.readStatusFor('notification-1'),
      NotificationReadStatus.read,
    );
    expect(repository.unreadCountCalls, greaterThanOrEqualTo(2));
  });

  test(
    'maps a foreign detail to an unavailable state without leaking it',
    () async {
      final repository = _FakeNotificationRepository()
        ..detailError = const ApiException(
          statusCode: 404,
          code: 'NOTIFICATION_NOT_FOUND',
          message: 'not found',
        );
      final controller = NotificationController(
        notificationRepository: repository,
      );

      final result = await controller.loadDetail('foreign-id');

      expect(result, isNull);
      expect(
        controller.detailStatusFor('foreign-id'),
        NotificationLoadStatus.unavailable,
      );
      expect(
        controller.detailErrorFor('foreign-id'),
        'This notification is no longer available.',
      );
    },
  );

  test('sends authorization failures to the auth boundary', () async {
    ApiException? authError;
    final repository = _FakeNotificationRepository()
      ..listError = const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'expired',
      );
    final controller = NotificationController(
      notificationRepository: repository,
      onAuthFailure: (error) async => authError = error,
    );

    await controller.refresh();

    expect(controller.listStatus, NotificationLoadStatus.unauthorized);
    expect(authError?.statusCode, 401);
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  ApiException? listError;
  ApiException? detailError;
  int unreadCountCalls = 0;
  final List<String> markedIds = <String>[];

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    int limit = 20,
    String? cursor,
  }) async {
    final error = listError;
    if (error != null) {
      throw error;
    }
    return CourierNotificationPage(
      items: <CourierNotification>[_notification],
      nextCursor: null,
      generatedAt: DateTime.utc(2026, 9, 20, 2),
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    unreadCountCalls++;
    return markedIds.isEmpty ? 1 : 0;
  }

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async {
    final error = detailError;
    if (error != null) {
      throw error;
    }
    return _notification;
  }

  @override
  Future<CourierNotification> markRead(String notificationId) async {
    markedIds.add(notificationId);
    return _notification.copyWith(readAt: DateTime.utc(2026, 9, 20, 2, 1));
  }
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
