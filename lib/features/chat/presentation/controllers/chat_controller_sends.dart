part of 'chat_controller.dart';

extension ChatControllerSends on ChatController {
  Future<bool> sendMessage(String text) async {
    final task = activeTask;
    final thread = activeThread;
    final body = text.trim();
    if (task == null ||
        body.isEmpty ||
        body.length > 2000 ||
        (threadStatus != ChatLoadStatus.loaded &&
            threadStatus != ChatLoadStatus.empty) ||
        sendStatus == ChatSendStatus.conflict ||
        (thread != null &&
            (thread.counterpartyRole != 'logistics' ||
                thread.sendAllowed != true))) {
      sendStatus = ChatSendStatus.validation;
      sendError = 'Enter a message of 1–2,000 characters in an active Logistics conversation.';
      _notify();
      return false;
    }
    if (!canRetry || sendStatus == ChatSendStatus.sending) return false;
    var attempt = pendingAttempt;
    if (attempt != null &&
        (attempt.body != body ||
            attempt.taskId != task.taskId ||
            (attempt.threadId != null && attempt.threadId != thread?.id))) {
      sendStatus = ChatSendStatus.uncertain;
      sendError =
          'Retry the same message, or discard the pending attempt first.';
      _notify();
      return false;
    }
    attempt ??= ChatSendAttempt(
      body: body,
      key: ChatController._newUuid(),
      leg: task.leg,
      taskId: task.taskId,
      counterpartyRole: 'logistics',
      threadId: thread?.id,
    );
    pendingAttempt = attempt;
    sendStatus = ChatSendStatus.sending;
    sendError = null;
    _notify();
    final epoch = _epoch;
    try {
      final result = attempt.threadId == null
          ? await repository.start(
              leg: attempt.leg,
              taskId: attempt.taskId,
              counterpartyRole: attempt.counterpartyRole,
              body: attempt.body,
              idempotencyKey: attempt.key,
            )
          : await repository.send(
              id: attempt.threadId!,
              body: attempt.body,
              idempotencyKey: attempt.key,
            );
      if (epoch != _epoch) return false;
      _threadRequestId++;
      _replaceThread(result.thread);
      _mergeMessages([result.message]);
      pendingAttempt = null;
      sendStatus = ChatSendStatus.saved;
      threadStatus = ChatLoadStatus.loaded;
      _notify();
      unawaited(refreshActive(silent: true));
      return true;
    } on ApiException catch (error) {
      if (epoch != _epoch) return false;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _authorizationFailure(error);
        return false;
      }
      if (error.statusCode == 422) {
        pendingAttempt = null;
        sendStatus = ChatSendStatus.validation;
        sendError = 'The message was rejected. Check its length and retry.';
      } else if (error.statusCode == 409) {
        sendStatus = ChatSendStatus.conflict;
        threadStatus = ChatLoadStatus.stale;
        sendError = 'This conversation changed. Refresh before sending again.';
        unawaited(refreshActive());
      } else {
        sendStatus = ChatSendStatus.uncertain;
        sendError = error.statusCode == 429
            ? 'Too many messages. Wait before retrying this exact message.'
            : 'The message may not have been saved. Retry this exact message.';
      }
      if (error.statusCode == 429) _startRetryDelay(error.retryAfter);
      _notify();
      return false;
    } on ApiContractException {
      if (epoch != _epoch) return false;
      sendStatus = ChatSendStatus.uncertain;
      sendError =
          'The send response was not understood. Retry this exact message.';
      _notify();
      return false;
    } on TokenStorageException {
      if (epoch != _epoch) return false;
      clear();
      sendStatus = ChatSendStatus.failed;
      sendError = 'Secure session storage is unavailable.';
      _notify();
      return false;
    }
  }

  void discardPendingAttempt() {
    pendingAttempt = null;
    sendStatus = ChatSendStatus.idle;
    sendError = null;
    _notify();
  }
}
