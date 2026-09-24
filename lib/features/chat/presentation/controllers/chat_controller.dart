import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_models.dart';

part 'chat_controller_reads.dart';
part 'chat_controller_sends.dart';
part 'chat_controller_errors.dart';

typedef ChatAuthFailureHandler = Future<void> Function(ApiException error);

enum ChatLoadStatus {
  idle,
  loading,
  loaded,
  empty,
  stale,
  offline,
  timeout,
  forbidden,
  consentRequired,
  unavailable,
  rateLimited,
  failed,
}

enum ChatSendStatus {
  idle,
  sending,
  saved,
  uncertain,
  validation,
  conflict,
  failed,
}

class ChatTaskContext {
  const ChatTaskContext({
    required this.leg,
    required this.taskId,
    this.reference,
  });

  final String leg;
  final String taskId;
  final String? reference;
}

class ChatSendAttempt {
  const ChatSendAttempt({
    required this.body,
    required this.key,
    required this.leg,
    required this.taskId,
    required this.counterpartyRole,
    this.threadId,
  });

  final String body;
  final String key;
  final String leg;
  final String taskId;
  final String counterpartyRole;
  final String? threadId;
}

class ChatController extends ChangeNotifier {
  ChatController({required this.repository, this.onAuthFailure});

  static const pollInterval = Duration(seconds: 30);
  static const maxInMemoryThreads = 100;
  static const maxInMemoryMessages = 100;

  final ChatRepository repository;
  final ChatAuthFailureHandler? onAuthFailure;

  List<ChatThread> threads = const [];
  String? nextInboxCursor;
  int? unreadCount;
  ChatLoadStatus inboxStatus = ChatLoadStatus.idle;
  String? inboxError;
  bool loadingMoreInbox = false;

  ChatThread? activeThread;
  ChatTaskContext? activeTask;
  List<ChatMessage> messages = const [];
  String? nextMessageCursor;
  ChatLoadStatus threadStatus = ChatLoadStatus.idle;
  String? threadError;
  bool loadingOlder = false;

  ChatSendStatus sendStatus = ChatSendStatus.idle;
  String? sendError;
  ChatSendAttempt? pendingAttempt;

  int _epoch = 0;
  int _inboxRequestId = 0;
  int _threadRequestId = 0;
  Timer? _pollTimer;
  Timer? _retryTimer;
  bool _disposed = false;

  bool get canRetry => _retryTimer == null;
  bool get canLoadMoreInbox => nextInboxCursor != null && !loadingMoreInbox;
  bool get canLoadOlder => nextMessageCursor != null && !loadingOlder;

  void startPollingInbox() {
    stopPolling();
    _pollTimer = Timer.periodic(
      pollInterval,
      (_) {
        if (inboxStatus != ChatLoadStatus.offline &&
            inboxStatus != ChatLoadStatus.timeout) {
          unawaited(loadInbox(silent: true));
        }
      },
    );
  }

  void startPollingThread() {
    stopPolling();
    _pollTimer = Timer.periodic(
      pollInterval,
      (_) {
        if (threadStatus != ChatLoadStatus.offline &&
            threadStatus != ChatLoadStatus.timeout) {
          unawaited(refreshActive(silent: true));
        }
      },
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    _epoch++;
    _inboxRequestId++;
    _threadRequestId++;
    stopPolling();
    _retryTimer?.cancel();
    _retryTimer = null;
    threads = const [];
    nextInboxCursor = null;
    unreadCount = null;
    inboxStatus = ChatLoadStatus.idle;
    inboxError = null;
    loadingMoreInbox = false;
    activeThread = null;
    activeTask = null;
    messages = const [];
    nextMessageCursor = null;
    threadStatus = ChatLoadStatus.idle;
    threadError = null;
    loadingOlder = false;
    sendStatus = ChatSendStatus.idle;
    sendError = null;
    pendingAttempt = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }
}
