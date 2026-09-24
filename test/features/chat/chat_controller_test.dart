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
  test(
    'timeout retains exact first-send body and UUID until confirmed',
    () async {
      final repository = _ChatRepository()..failFirstStart = true;
      final controller = ChatController(repository: repository);
      await controller.openTask(
        const ChatTaskContext(leg: 'first_mile', taskId: 'task-1'),
      );

      expect(await controller.sendMessage(' Hello '), isFalse);
      expect(controller.messages, isEmpty);
      expect(controller.sendStatus, ChatSendStatus.uncertain);
      final key = controller.pendingAttempt!.key;
      expect(
        key,
        matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
      );

      expect(await controller.sendMessage('Changed text'), isFalse);
      expect(repository.startKeys, hasLength(1));
      expect(await controller.sendMessage('Hello'), isTrue);
      expect(repository.startKeys, [key, key]);
      expect(repository.startBodies, ['Hello', 'Hello']);
      expect(controller.messages.single.id, 'message-1');
      expect(controller.pendingAttempt, isNull);
      controller.dispose();
    },
  );

  test('clears private history and pending draft on session end', () async {
    final repository = _ChatRepository()..failFirstStart = true;
    final controller = ChatController(repository: repository);
    await controller.openTask(
      const ChatTaskContext(leg: 'first_mile', taskId: 'task-1'),
    );
    await controller.sendMessage('Sensitive draft');
    expect(controller.pendingAttempt, isNotNull);

    controller.clear();

    expect(controller.activeTask, isNull);
    expect(controller.pendingAttempt, isNull);
    expect(controller.threads, isEmpty);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });

  test('keeps existing messages on offline read failure', () async {
    final repository = _ChatRepository();
    final controller = ChatController(repository: repository);
    await controller.openThread(_thread());
    expect(controller.messages.single.body, 'Hello');
    repository.readError = const ApiException.network('private network detail');

    await controller.refreshActive();

    expect(controller.threadStatus, ChatLoadStatus.offline);
    expect(controller.messages.single.body, 'Hello');
    expect(controller.threadError, isNot(contains('private')));
    expect(await controller.sendMessage('Do not queue this'), isFalse);
    expect(repository.sendKeys, isEmpty);
    controller.dispose();
  });

  test('409 prevents another send until the conflicting attempt is discarded', () async {
    final repository = _ChatRepository()
      ..sendError = const ApiException(
        statusCode: 409,
        code: 'CONVERSATION_READ_ONLY',
        message: 'private server detail',
      );
    final controller = ChatController(repository: repository);
    await controller.openThread(_thread());

    expect(await controller.sendMessage('Status?'), isFalse);
    expect(controller.sendStatus, ChatSendStatus.conflict);
    expect(controller.pendingAttempt, isNotNull);
    expect(await controller.sendMessage('Status?'), isFalse);
    expect(repository.sendKeys, hasLength(1));

    controller.discardPendingAttempt();
    expect(controller.pendingAttempt, isNull);
    controller.dispose();
  });

  test('422 releases rejected request key and keeps message unsaved', () async {
    final repository = _ChatRepository()
      ..startError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_FAILED',
        message: 'private server detail',
      );
    final controller = ChatController(repository: repository);
    await controller.openTask(
      const ChatTaskContext(leg: 'first_mile', taskId: 'task-1'),
    );

    expect(await controller.sendMessage('Message'), isFalse);
    expect(controller.messages, isEmpty);
    expect(controller.pendingAttempt, isNull);
    expect(controller.sendStatus, ChatSendStatus.validation);
    controller.dispose();
  });

  test('policy denial clears chat and hands off to consent gate', () async {
    final repository = _ChatRepository()
      ..listError = const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: 'private server detail',
      );
    var authCalled = false;
    final controller = ChatController(
      repository: repository,
      onAuthFailure: (error) async {
        authCalled = error.code == 'POLICY_CONSENT_REQUIRED';
      },
    );

    await controller.loadInbox();

    expect(authCalled, isTrue);
    expect(controller.threads, isEmpty);
    expect(controller.inboxStatus, ChatLoadStatus.consentRequired);
    controller.dispose();
  });

  test('blocks sends to non-Logistics counterpart in this rollout', () async {
    final repository = _ChatRepository();
    final controller = ChatController(repository: repository);
    final seller = ChatThread.fromJson({
      ..._threadJson,
      'counterparty_role': 'seller',
      'kind': 'courier_seller',
    });
    repository.detailThread = seller;
    await controller.openThread(seller);

    expect(await controller.sendMessage('Hello'), isFalse);
    expect(repository.sendKeys, isEmpty);
    controller.dispose();
  });

  test(
    'scoped 404 removes previously visible private thread messages',
    () async {
      final repository = _ChatRepository();
      final controller = ChatController(repository: repository);
      await controller.openThread(_thread());
      expect(controller.messages, isNotEmpty);
      repository.readError = const ApiException(
        statusCode: 404,
        code: 'NOT_FOUND',
        message: 'private server detail',
      );

      await controller.refreshActive();

      expect(controller.threadStatus, ChatLoadStatus.unavailable);
      expect(controller.activeThread, isNull);
      expect(controller.messages, isEmpty);
      controller.dispose();
    },
  );

  test('401 clears chat state and hands off to auth', () async {
    final repository = _ChatRepository()
      ..listError = const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'private server detail',
      );
    var authCalled = false;
    final controller = ChatController(
      repository: repository,
      onAuthFailure: (error) async {
        authCalled = error.statusCode == 401;
      },
    );

    await controller.loadInbox();

    expect(authCalled, isTrue);
    expect(controller.threads, isEmpty);
    expect(controller.inboxStatus, ChatLoadStatus.forbidden);
    controller.dispose();
  });

  test('429 respects retry-after before another inbox read', () async {
    final repository = _ChatRepository()
      ..listError = const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'private server detail',
        retryAfter: Duration(milliseconds: 40),
      );
    final controller = ChatController(repository: repository);
    await controller.loadInbox();
    expect(controller.canRetry, isFalse);
    await controller.loadInbox();
    expect(repository.listCount, 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.canRetry, isTrue);
    controller.dispose();
  });

  test('ignores an obsolete inbox read after chat is cleared', () async {
    final pending = Completer<ChatPage<ChatThread>>();
    final repository = _ChatRepository()..pendingList = pending;
    final controller = ChatController(repository: repository);
    final load = controller.loadInbox();
    controller.clear();
    pending.complete(
      ChatPage(items: [_thread()], nextCursor: null, unreadCount: 0),
    );
    await load;
    expect(controller.threads, isEmpty);
    controller.dispose();
  });

  testWidgets(
    'Logistics task chat requires a saved response before showing a message',
    (tester) async {
      final repository = _ChatRepository()..failFirstStart = true;
      final chat = ChatController(repository: repository);
      final auth = AuthController(
        authRepository: _UnusedAuthRepository(),
        dashboardRepository: _UnusedDashboardRepository(),
      )..status = AuthStatus.authenticated;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatThreadScreen(
            controller: chat,
            authController: auth,
            task: const ChatTaskContext(leg: 'first_mile', taskId: 'task-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('No task conversation found'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(chat.messages, isEmpty);
      expect(find.textContaining('may not have been saved'), findsOneWidget);

      await tester.tap(find.byTooltip('Retry same message'));
      await tester.pump();
      expect(chat.messages.single.id, 'message-1');
      expect(chat.pendingAttempt, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
      auth.dispose();
    },
  );

  testWidgets('Seller thread is read-only while counterpart screen is absent', (
    tester,
  ) async {
    final seller = ChatThread.fromJson({
      ..._threadJson,
      'counterparty_role': 'seller',
      'kind': 'courier_seller',
    });
    final repository = _ChatRepository()..detailThread = seller;
    final chat = ChatController(repository: repository);
    final auth = AuthController(
      authRepository: _UnusedAuthRepository(),
      dashboardRepository: _UnusedDashboardRepository(),
    )..status = AuthStatus.authenticated;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatThreadScreen(
          controller: chat,
          authController: auth,
          thread: seller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Read-only conversation'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    chat.dispose();
    auth.dispose();
  });
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedDashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ChatThread _thread() => ChatThread.fromJson(_threadJson);

const _threadJson = <String, dynamic>{
  'id': 'thread-1',
  'kind': 'logistics_courier',
  'leg': 'first_mile',
  'task_id': 'task-1',
  'counterparty_role': 'logistics',
  'unread_count': 0,
  'last_sequence': 1,
  'last_read_sequence': 0,
  'send_allowed': true,
};

ChatMessage _message() => ChatMessage.fromJson(const {
  'id': 'message-1',
  'conversation_id': 'thread-1',
  'sequence': 1,
  'sender_role': 'logistics',
  'mine': false,
  'body': 'Hello',
  'created_at': '2026-09-24T00:00:00Z',
});

class _ChatRepository implements ChatRepository {
  bool failFirstStart = false;
  Object? readError;
  Object? listError;
  Object? startError;
  Object? sendError;
  Completer<ChatPage<ChatThread>>? pendingList;
  int listCount = 0;
  ChatThread? detailThread;
  final List<String> startKeys = [];
  final List<String> startBodies = [];
  final List<String> sendKeys = [];

  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async {
    listCount++;
    if (listError case final error?) throw error;
    if (pendingList case final pending?) return pending.future;
    return const ChatPage(items: [], nextCursor: null, unreadCount: 0);
  }

  @override
  Future<ChatThread> detail(String id) async {
    if (readError case final error?) throw error;
    return detailThread ?? _thread();
  }

  @override
  Future<ChatPage<ChatMessage>> messages(
    String id, {
    String? cursor,
    int limit = 20,
  }) async {
    return ChatPage(items: [_message()], nextCursor: null);
  }

  @override
  Future<ChatSendResult> start({
    required String leg,
    required String taskId,
    required String counterpartyRole,
    required String body,
    required String idempotencyKey,
  }) async {
    startKeys.add(idempotencyKey);
    startBodies.add(body);
    if (startError case final error?) throw error;
    if (failFirstStart) {
      failFirstStart = false;
      throw const ApiException.network(
        'private timeout',
        networkFailure: ApiNetworkFailure.timeout,
      );
    }
    return ChatSendResult(thread: _thread(), message: _message());
  }

  @override
  Future<ChatSendResult> send({
    required String id,
    required String body,
    required String idempotencyKey,
  }) async {
    sendKeys.add(idempotencyKey);
    if (sendError case final error?) throw error;
    return ChatSendResult(thread: _thread(), message: _message());
  }

  @override
  Future<ChatThread> markRead(String id, int lastReadSequence) async =>
      _thread();
}
