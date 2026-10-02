import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/chat_thread_screen.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Buyer task context permits only final mile', () {
    expect(_task.canCompose, isTrue);
    expect(
      const ChatTaskContext(
        leg: 'first_mile',
        taskId: 'task-1',
        counterpartyRole: 'customer',
      ).canCompose,
      isFalse,
    );
  });
  test(
    'Buyer start timeout preserves task, body and exact UUID retry',
    () async {
      final repo = _Repo()
        ..startError = const ApiException.network(
          'private',
          networkFailure: ApiNetworkFailure.timeout,
        );
      final controller = ChatController(repository: repo);
      await controller.openTask(_task);
      expect(await controller.sendMessage(' Hello Buyer '), isFalse);
      final attempt = controller.pendingAttempt!;
      expect(attempt.leg, 'final_mile');
      expect(attempt.counterpartyRole, 'customer');
      expect(controller.messages, isEmpty);
      expect(await controller.sendMessage('Different text'), isFalse);
      repo.startError = null;
      expect(await controller.sendMessage('Hello Buyer'), isTrue);
      expect(repo.keys, [attempt.key, attempt.key]);
      expect(repo.bodies, ['Hello Buyer', 'Hello Buyer']);
      expect(controller.pendingAttempt, isNull);
      controller.dispose();
    },
  );
  test(
    'existing Buyer reply rechecks sendability immediately before sending',
    () async {
      final repo = _Repo();
      final controller = ChatController(repository: repo);
      await controller.openThread(_buyer());
      repo.allowed = false;
      expect(await controller.sendMessage('Do not send'), isFalse);
      expect(repo.keys, isEmpty);
      expect(controller.activeThread?.sendAllowed, isFalse);
      expect(controller.pendingAttempt, isNull);
      controller.discardPendingAttempt();
      expect(await controller.sendMessage('Still blocked'), isFalse);
      expect(repo.keys, isEmpty);
      controller.dispose();
    },
  );
  test('existing Buyer thread requires send_allowed true', () async {
    final repo = _Repo()..allowed = null;
    final controller = ChatController(repository: repo);
    await controller.openThread(_buyer());
    expect(await controller.sendMessage('Hello'), isFalse);
    expect(repo.keys, isEmpty);
    controller.dispose();
  });
  test(
    'existing Buyer timeout retry keeps its key; a new reply gets a new key',
    () async {
      final repo = _Repo()
        ..sendError = const ApiException.network(
          'private',
          networkFailure: ApiNetworkFailure.timeout,
        );
      final controller = ChatController(repository: repo);
      await controller.openThread(_buyer());
      expect(await controller.sendMessage('Hello Buyer'), isFalse);
      final key = controller.pendingAttempt!.key;
      repo.sendError = null;
      expect(await controller.sendMessage('Hello Buyer'), isTrue);
      expect(repo.keys, [key, key]);
      expect(await controller.sendMessage('Another reply'), isTrue);
      expect(repo.keys.last, isNot(key));
      controller.dispose();
    },
  );
  test('offline Buyer refresh preserves history but cannot send', () async {
    final repo = _Repo();
    final controller = ChatController(repository: repo);
    await controller.openThread(_buyer());
    repo.readError = const ApiException.network('private');
    await controller.refreshActive();
    expect(controller.messages.single.body, 'Hello Buyer');
    expect(controller.threadStatus, ChatLoadStatus.offline);
    expect(await controller.sendMessage('Offline write'), isFalse);
    expect(repo.keys, isEmpty);
    controller.dispose();
  });
  test('Buyer read response cannot switch the task context', () async {
    final repo = _Repo()
      ..unreadCount = 1
      ..readTaskId = 'foreign-task';
    final controller = ChatController(repository: repo);
    await controller.openThread(_buyer());
    expect(controller.activeThread?.taskId, 'task-1');
    expect(controller.activeThread?.counterpartyRole, 'customer');
    expect(controller.threadError, contains('read marker was not understood'));
    controller.dispose();
  });
  for (final status in [401, 403, 404]) {
    test(
      'Buyer send denial $status clears private state and pending attempt',
      () async {
        var authCalled = false;
        final repo = _Repo()
          ..sendError = ApiException(
            statusCode: status,
            code: 'DENIED',
            message: 'private',
          );
        final controller = ChatController(
          repository: repo,
          onAuthFailure: (_) async {
            authCalled = true;
          },
        );
        await controller.openThread(_buyer());
        expect(await controller.sendMessage('Private draft'), isFalse);
        expect(controller.messages, isEmpty);
        expect(controller.pendingAttempt, isNull);
        expect(controller.activeTask, isNull);
        expect(authCalled, status != 404);
        expect(await controller.sendMessage('Again'), isFalse);
        expect(repo.keys, hasLength(1));
        controller.dispose();
      },
    );
  }
  test(
    'Buyer reassignment conflict blocks further sends and is not saved',
    () async {
      final repo = _Repo()
        ..sendError = const ApiException(
          statusCode: 409,
          code: 'TASK_NOT_ACTIVE',
          message: 'private',
        );
      final controller = ChatController(repository: repo);
      await controller.openThread(_buyer());
      expect(await controller.sendMessage('Hello'), isFalse);
      expect(await controller.sendMessage('Hello'), isFalse);
      expect(controller.sendStatus, ChatSendStatus.conflict);
      expect(await controller.sendMessage('Hello'), isFalse);
      expect(repo.keys, hasLength(1));
      controller.dispose();
    },
  );
  test(
    'clearing Buyer chat during send ignores obsolete successful response',
    () async {
      final pending = Completer<ChatSendResult>();
      final repo = _Repo()..pendingStart = pending;
      final controller = ChatController(repository: repo);
      await controller.openTask(_task);
      final send = controller.sendMessage('Private draft');
      controller.clear();
      pending.complete(_result());
      expect(await send, isFalse);
      expect(controller.messages, isEmpty);
      expect(controller.pendingAttempt, isNull);
      controller.dispose();
    },
  );
  for (final allowed in [false, null]) {
    testWidgets('Buyer composer stays read-only with send_allowed $allowed', (
      tester,
    ) async {
      final repo = _Repo()..allowed = allowed;
      final controller = ChatController(repository: repo);
      final auth = _auth();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatThreadScreen(
            controller: controller,
            authController: auth,
            thread: _buyer(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Read-only conversation'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      auth.dispose();
    });
  }
  testWidgets(
    'Buyer composer preserves uncertain draft and clears on account-scope loss',
    (tester) async {
      final repo = _Repo()
        ..startError = const ApiException.network(
          'private',
          networkFailure: ApiNetworkFailure.timeout,
        );
      final controller = ChatController(repository: repo);
      final auth = _auth();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatThreadScreen(
            controller: controller,
            authController: auth,
            task: _task,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Private draft');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsOneWidget);
      expect(find.byTooltip('Retry same message'), findsOneWidget);
      controller.clear();
      await controller.openTask(_task);
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      auth.dispose();
    },
  );
  testWidgets('Buyer polling pauses in background and after leaving thread', (
    tester,
  ) async {
    final repo = _Repo();
    final controller = ChatController(repository: repo);
    final auth = _auth();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: ChatThreadScreen(
          controller: controller,
          authController: auth,
          thread: _buyer(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = repo.detailCalls;
    await tester.pump(ChatController.pollInterval);
    await tester.pump();
    expect(repo.detailCalls, greaterThan(initial));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = repo.detailCalls;
    await tester.pump(ChatController.pollInterval * 2);
    expect(repo.detailCalls, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    final left = repo.detailCalls;
    await tester.pump(ChatController.pollInterval * 2);
    expect(repo.detailCalls, left);
    controller.dispose();
    auth.dispose();
  });
}

const _task = ChatTaskContext(
  leg: 'final_mile',
  taskId: 'task-1',
  counterpartyRole: 'customer',
  reference: 'ORD-123',
);
ChatThread _buyer({
  bool? allowed = true,
  String taskId = 'task-1',
  int unreadCount = 0,
}) => ChatThread(
  id: 'thread-1',
  kind: 'courier_customer',
  leg: 'final_mile',
  taskId: taskId,
  taskReference: 'ORD-123',
  counterpartyRole: 'customer',
  counterpartyLabel: 'Buyer',
  unreadCount: unreadCount,
  lastSequence: 1,
  lastReadSequence: 0,
  sendAllowed: allowed,
);
ChatMessage _message() => ChatMessage(
  id: 'message-1',
  conversationId: 'thread-1',
  sequence: 1,
  senderRole: 'customer',
  mine: false,
  body: 'Hello Buyer',
  createdAt: DateTime.utc(2026, 10, 2),
);
ChatSendResult _result() =>
    ChatSendResult(thread: _buyer(), message: _message());
AuthController _auth() => AuthController(
  authRepository: _UnusedAuth(),
  dashboardRepository: _UnusedDashboard(),
)..status = AuthStatus.authenticated;

class _UnusedAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Repo implements ChatRepository {
  bool? allowed = true;
  int unreadCount = 0;
  String readTaskId = 'task-1';
  Object? readError;
  Object? sendError;
  Object? startError;
  Completer<ChatSendResult>? pendingStart;
  int detailCalls = 0;
  final keys = <String>[];
  final bodies = <String>[];
  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async => const ChatPage(items: [], nextCursor: null, unreadCount: 0);
  @override
  Future<ChatThread> detail(String id) async {
    detailCalls++;
    if (readError case final error?) throw error;
    return _buyer(allowed: allowed, unreadCount: unreadCount);
  }

  @override
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  }) async => ChatPage(items: [_message()], nextCursor: null);
  @override
  Future<ChatSendResult> start({
    required String leg,
    required String taskId,
    required String counterpartyRole,
    required String body,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    bodies.add(body);
    if (startError case final error?) throw error;
    if (pendingStart case final pending?) return pending.future;
    return _result();
  }

  @override
  Future<ChatSendResult> send({
    required String id,
    required String body,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    bodies.add(body);
    if (sendError case final error?) throw error;
    return _result();
  }

  @override
  Future<ChatThread> markRead(String id, int lastReadSequence) async =>
      _buyer(allowed: allowed, taskId: readTaskId);
}
