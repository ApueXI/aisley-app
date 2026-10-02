import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [
    'delivery_accepted',
    'picked_up_from_hub',
    'in_transit',
    'out_for_delivery',
  ]) {
    testWidgets('Message Buyer is available for accepted final-mile $status', (
      tester,
    ) async {
      final task = _task(status);
      final chat = ChatController(repository: _ChatRepository());
      final delivery = DeliveryController(
        deliveryRepository: _DeliveryRepository(task),
      )..tasks = [task];
      final auth = _auth();
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: auth,
            deliveryController: delivery,
            task: task,
            chatController: chat,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Message Buyer'), findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'Message Buyer'))
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('Message Buyer'));
      await tester.pumpAndSettle();
      expect(chat.activeTask?.taskId, task.id);
      expect(chat.activeTask?.leg, 'final_mile');
      expect(chat.activeTask?.counterpartyRole, 'customer');
      expect(find.textContaining('Final mile · ORD-123'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Send message'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      delivery.dispose();
      auth.dispose();
    });
  }
  for (final status in [
    'delivery_assigned',
    'delivered',
    'rejected',
    'cancelled',
    'unknown',
  ]) {
    testWidgets('Message Buyer is hidden for final-mile $status', (
      tester,
    ) async {
      final task = _task(status);
      final chat = ChatController(repository: _ChatRepository());
      final delivery = DeliveryController(
        deliveryRepository: _DeliveryRepository(task),
      )..tasks = [task];
      final auth = _auth();
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: auth,
            deliveryController: delivery,
            task: task,
            chatController: chat,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Message Buyer'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      delivery.dispose();
      auth.dispose();
    });
  }
  test('first-mile acceptance cannot grant Buyer chat', () {
    expect(
      ChatTaskContext.canMessageBuyer(
        const PickupTask(
          id: 'first-task',
          leg: PickupTaskLeg.firstMile,
          rawStatus: 'accepted',
        ),
      ),
      isFalse,
    );
  });
  testWidgets('Buyer action remains accessible at large text scale', (
    tester,
  ) async {
    final task = _task('delivery_accepted');
    final chat = ChatController(repository: _ChatRepository());
    final delivery = DeliveryController(
      deliveryRepository: _DeliveryRepository(task),
    )..tasks = [task];
    final auth = _auth();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DeliveryTaskScreen(
          authController: auth,
          deliveryController: delivery,
          task: task,
          chatController: chat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Message Buyer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
    chat.dispose();
    delivery.dispose();
    auth.dispose();
  });
}

PickupTask _task(String status) => PickupTask(
  id: 'final-task',
  leg: PickupTaskLeg.finalMile,
  rawStatus: status,
  revision: 4,
  order: const PickupOrderReference(reference: 'ORD-123'),
);
AuthController _auth() => AuthController(
  authRepository: _AuthRepository(),
  dashboardRepository: _DashboardRepository(),
)..status = AuthStatus.authenticated;

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _ChatRepository implements ChatRepository {
  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async => const ChatPage(items: [], nextCursor: null, unreadCount: 0);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DeliveryRepository implements DeliveryRepository {
  _DeliveryRepository(this.task);
  final PickupTask task;
  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async =>
      DeliveryContext(
        taskId: task.id,
        status: task.rawStatus,
        revision: task.revision,
        hub: const PickupLocation(name: 'Hub'),
        destination: const PickupLocation(cityMunicipality: 'City'),
      );
  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async =>
      CompletionProjection(
        taskId: task.id,
        taskStatus: task.rawStatus,
        completionStatus: null,
        revision: task.revision,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
