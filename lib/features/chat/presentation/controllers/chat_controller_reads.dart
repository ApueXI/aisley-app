part of 'chat_controller.dart';

extension ChatControllerReads on ChatController {
  Future<void> loadInbox({bool silent = false}) async {
    if (!canRetry) return;
    final epoch = _epoch;
    final requestId = ++_inboxRequestId;
    loadingMoreInbox = false;
    if (!silent) inboxStatus = ChatLoadStatus.loading;
    inboxError = null;
    _notify();
    try {
      final page = await repository.list();
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      threads = page.items
          .take(ChatController.maxInMemoryThreads)
          .toList(growable: false);
      nextInboxCursor = page.nextCursor;
      unreadCount = page.unreadCount;
      inboxStatus = threads.isEmpty
          ? ChatLoadStatus.empty
          : ChatLoadStatus.loaded;
      _notify();
    } on ApiException catch (error) {
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      await _readFailure(error, inbox: true);
    } on ApiContractException {
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      inboxStatus = threads.isEmpty
          ? ChatLoadStatus.failed
          : ChatLoadStatus.stale;
      inboxError = 'The conversation list did not match the API contract.';
      _notify();
    } on TokenStorageException {
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      _storageFailure(inbox: true);
    }
  }

  Future<void> loadMoreInbox() async {
    final cursor = nextInboxCursor;
    if (cursor == null || loadingMoreInbox || !canRetry) return;
    final epoch = _epoch;
    final requestId = _inboxRequestId;
    loadingMoreInbox = true;
    _notify();
    try {
      final page = await repository.list(cursor: cursor);
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      final byId = {for (final item in threads) item.id: item};
      for (final item in page.items) {
        byId[item.id] = item;
      }
      threads = byId.values
          .take(ChatController.maxInMemoryThreads)
          .toList(growable: false);
      nextInboxCursor = page.nextCursor;
      unreadCount = page.unreadCount;
      inboxStatus = ChatLoadStatus.loaded;
      loadingMoreInbox = false;
      _notify();
    } on ApiException catch (error) {
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      loadingMoreInbox = false;
      await _readFailure(error, inbox: true);
    } on ApiContractException {
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      loadingMoreInbox = false;
      inboxStatus = ChatLoadStatus.stale;
      inboxError = 'Older conversations could not be loaded.';
      _notify();
    } on TokenStorageException {
      if (epoch != _epoch || requestId != _inboxRequestId) return;
      _storageFailure(inbox: true);
    }
  }

  Future<void> openThread(ChatThread thread) async {
    _epoch++;
    _threadRequestId++;
    activeThread = thread;
    activeTask = ChatTaskContext(
      leg: thread.leg,
      taskId: thread.taskId,
      reference: thread.taskReference,
    );
    messages = const [];
    nextMessageCursor = null;
    loadingOlder = false;
    if (pendingAttempt == null) sendStatus = ChatSendStatus.idle;
    threadStatus = ChatLoadStatus.loading;
    threadError = null;
    _notify();
    await refreshActive();
  }

  Future<void> openTask(ChatTaskContext task) async {
    _epoch++;
    _threadRequestId++;
    activeThread = null;
    activeTask = task;
    messages = const [];
    nextMessageCursor = null;
    loadingOlder = false;
    if (pendingAttempt == null) sendStatus = ChatSendStatus.idle;
    threadStatus = ChatLoadStatus.loading;
    threadError = null;
    _notify();
    await _findTaskThread(task);
  }

  Future<void> _findTaskThread(ChatTaskContext task) async {
    final epoch = _epoch;
    final requestId = ++_threadRequestId;
    loadingOlder = false;
    try {
      String? cursor;
      for (var pageNumber = 0; pageNumber < 10; pageNumber++) {
        final page = await repository.list(
          leg: task.leg,
          cursor: cursor,
          limit: 50,
        );
        if (epoch != _epoch || requestId != _threadRequestId) return;
        for (final thread in page.items) {
          if (thread.taskId == task.taskId &&
              thread.counterpartyRole == 'logistics') {
            activeThread = thread;
            await refreshActive();
            return;
          }
        }
        cursor = page.nextCursor;
        if (cursor == null) break;
      }
      if (epoch != _epoch || requestId != _threadRequestId) return;
      if (cursor != null) {
        threadStatus = ChatLoadStatus.failed;
        threadError = 'This task conversation is beyond the available inbox pages. Open the inbox to find it.';
        _notify();
        return;
      }
      threadStatus = ChatLoadStatus.empty;
      _notify();
    } on ApiException catch (error) {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      await _readFailure(error, inbox: false);
    } on ApiContractException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      threadStatus = ChatLoadStatus.failed;
      threadError = 'This conversation could not be loaded safely.';
      _notify();
    } on TokenStorageException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      _storageFailure(inbox: false);
    }
  }

  Future<void> refreshActive({bool silent = false}) async {
    final thread = activeThread;
    if (thread == null) {
      final task = activeTask;
      if (task != null) await _findTaskThread(task);
      return;
    }
    if (!canRetry) return;
    final epoch = _epoch;
    final requestId = ++_threadRequestId;
    loadingOlder = false;
    if (!silent) threadStatus = ChatLoadStatus.loading;
    threadError = null;
    _notify();
    try {
      final detail = await repository.detail(thread.id);
      final page = await repository.messages(thread.id);
      if (epoch != _epoch ||
          requestId != _threadRequestId ||
          activeThread?.id != thread.id) {
        return;
      }
      _replaceThread(detail);
      _mergeMessages(page.items, replace: !silent);
      nextMessageCursor = page.nextCursor;
      threadStatus = messages.isEmpty
          ? ChatLoadStatus.empty
          : ChatLoadStatus.loaded;
      _notify();
      await _markVisibleRead(epoch, requestId);
    } on ApiException catch (error) {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      await _readFailure(error, inbox: false);
    } on ApiContractException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      threadStatus = messages.isEmpty
          ? ChatLoadStatus.failed
          : ChatLoadStatus.stale;
      threadError = 'This conversation did not match the API contract.';
      _notify();
    } on TokenStorageException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      _storageFailure(inbox: false);
    }
  }

  Future<void> loadOlder() async {
    final thread = activeThread;
    final cursor = nextMessageCursor;
    if (thread == null || cursor == null || loadingOlder || !canRetry) return;
    final epoch = _epoch;
    final requestId = _threadRequestId;
    loadingOlder = true;
    _notify();
    try {
      final page = await repository.messages(thread.id, cursor: cursor);
      if (epoch != _epoch ||
          requestId != _threadRequestId ||
          activeThread?.id != thread.id) {
        return;
      }
      _mergeMessages(page.items);
      nextMessageCursor = page.nextCursor;
      loadingOlder = false;
      _notify();
    } on ApiException catch (error) {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      loadingOlder = false;
      await _readFailure(error, inbox: false);
    } on ApiContractException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      loadingOlder = false;
      threadError = 'Older messages could not be loaded.';
      _notify();
    } on TokenStorageException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      _storageFailure(inbox: false);
    }
  }

  Future<void> _markVisibleRead(int epoch, int requestId) async {
    final thread = activeThread;
    if (thread == null || thread.unreadCount == 0 || messages.isEmpty) return;
    final lastVisible = messages.last.sequence;
    if (lastVisible <= (thread.lastReadSequence ?? 0)) return;
    try {
      final updated = await repository.markRead(thread.id, lastVisible);
      if (epoch != _epoch ||
          requestId != _threadRequestId ||
          activeThread?.id != thread.id) {
        return;
      }
      _replaceThread(updated);
      _notify();
    } on ApiException catch (error) {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _authorizationFailure(error);
      } else {
        threadError = 'Messages loaded, but the read marker was not saved.';
        _notify();
      }
    } on ApiContractException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      threadError = 'Messages loaded, but the read marker was not understood.';
      _notify();
    } on TokenStorageException {
      if (epoch != _epoch || requestId != _threadRequestId) return;
      _storageFailure(inbox: false);
    }
  }

  void _replaceThread(ChatThread thread) {
    activeThread = thread;
    final byId = {for (final item in threads) item.id: item};
    byId[thread.id] = thread;
    threads = byId.values
        .take(ChatController.maxInMemoryThreads)
        .toList(growable: false);
  }

  void _mergeMessages(List<ChatMessage> incoming, {bool replace = false}) {
    final threadId = activeThread?.id;
    final byId = <String, ChatMessage>{
      if (!replace)
        for (final message in messages) message.id: message,
    };
    for (final message in incoming) {
      if (message.conversationId != threadId) {
        throw const ApiContractException('chat.message.conversation_id');
      }
      byId[message.id] = message;
    }
    final sorted = byId.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    messages = sorted.length > ChatController.maxInMemoryMessages
        ? sorted.sublist(sorted.length - ChatController.maxInMemoryMessages)
        : sorted;
  }
}
