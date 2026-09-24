part of 'chat_controller.dart';

extension ChatControllerErrors on ChatController {
  Future<void> _readFailure(ApiException error, {required bool inbox}) async {
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _authorizationFailure(error);
      return;
    }
    final hasData = inbox ? threads.isNotEmpty : messages.isNotEmpty;
    final state = switch (error.statusCode) {
      404 => ChatLoadStatus.unavailable,
      429 => ChatLoadStatus.rateLimited,
      null when error.networkFailure == ApiNetworkFailure.timeout =>
        ChatLoadStatus.timeout,
      null => ChatLoadStatus.offline,
      _ => hasData ? ChatLoadStatus.stale : ChatLoadStatus.failed,
    };
    final message = switch (state) {
      ChatLoadStatus.unavailable => 'This conversation is no longer available.',
      ChatLoadStatus.rateLimited =>
        'Too many chat requests. Wait before retrying.',
      ChatLoadStatus.timeout =>
        'Chat timed out. Check your connection and retry.',
      ChatLoadStatus.offline => 'Chat is offline. Reconnect and retry.',
      _ => 'Chat could not be refreshed. Retry to check the latest state.',
    };
    if (error.statusCode == 429) _startRetryDelay(error.retryAfter);
    if (error.statusCode == 404) {
      if (inbox) {
        threads = const [];
        nextInboxCursor = null;
        unreadCount = null;
      } else {
        activeThread = null;
        activeTask = null;
        messages = const [];
        nextMessageCursor = null;
      }
    }
    if (inbox) {
      inboxStatus = state;
      inboxError = message;
    } else {
      threadStatus = state;
      threadError = message;
    }
    _notify();
  }

  Future<void> _authorizationFailure(ApiException error) async {
    clear();
    final state = error.code == 'POLICY_CONSENT_REQUIRED'
        ? ChatLoadStatus.consentRequired
        : ChatLoadStatus.forbidden;
    inboxStatus = state;
    threadStatus = state;
    _notify();
    await onAuthFailure?.call(error);
  }

  void _storageFailure({required bool inbox}) {
    clear();
    if (inbox) {
      inboxStatus = ChatLoadStatus.failed;
      inboxError = 'Secure session storage is unavailable.';
    } else {
      threadStatus = ChatLoadStatus.failed;
      threadError = 'Secure session storage is unavailable.';
    }
    _notify();
  }

  void _startRetryDelay(Duration? retryAfter) {
    _retryTimer?.cancel();
    _retryTimer = Timer(retryAfter ?? const Duration(seconds: 1), () {
      _retryTimer = null;
      _notify();
    });
  }
}
