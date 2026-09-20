part of 'notification_controller.dart';

extension NotificationControllerErrors on NotificationController {
  Future<void> _applyListFailure(
    Object error, {
    bool forLoadMore = false,
  }) async {
    final status = _loadStatusFor(error, allowUnavailable: false);
    final message = _messageFor(error);
    if (forLoadMore) {
      loadMoreErrorMessage = message;
    } else {
      listErrorMessage = message;
    }
    listStatus = status == NotificationLoadStatus.failed && items.isNotEmpty
        ? NotificationLoadStatus.stale
        : status;
    await _handleAuthBoundary(error);
    _notify();
  }

  Future<void> _applyCountFailure(Object error) async {
    countStatus = _loadStatusFor(error, allowUnavailable: false);
    countErrorMessage = _messageFor(error);
    await _handleAuthBoundary(error);
    _notify();
  }

  Future<void> _applyDetailFailure(String id, Object error) async {
    detailStatuses[id] = _loadStatusFor(error, allowUnavailable: true);
    detailErrors[id] = _messageFor(error);
    await _handleAuthBoundary(error);
    _notify();
  }

  Future<void> _applyReadFailure(String id, Object error) async {
    readStatuses[id] = _readStatusFor(error);
    readErrors[id] = _messageFor(error);
    await _handleAuthBoundary(error);
    _notify();
  }

  NotificationLoadStatus _loadStatusFor(
    Object error, {
    required bool allowUnavailable,
  }) {
    if (error is TokenStorageException) {
      return NotificationLoadStatus.secureStorageFailure;
    }
    if (error is ApiContractException) {
      return NotificationLoadStatus.failed;
    }
    if (error is! ApiException) {
      return NotificationLoadStatus.failed;
    }
    if (error.statusCode == 401) {
      return NotificationLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? NotificationLoadStatus.consentRequired
          : NotificationLoadStatus.forbidden;
    }
    if (error.statusCode == 404 && allowUnavailable) {
      return NotificationLoadStatus.unavailable;
    }
    if (error.statusCode == 429) {
      _startRateLimitTimer(error.retryAfter);
      return NotificationLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? NotificationLoadStatus.timeout
          : NotificationLoadStatus.offline;
    }
    return NotificationLoadStatus.failed;
  }

  NotificationReadStatus _readStatusFor(Object error) {
    if (error is TokenStorageException) {
      return NotificationReadStatus.secureStorageFailure;
    }
    if (error is! ApiException) {
      return NotificationReadStatus.failed;
    }
    if (error.statusCode == 401) {
      return NotificationReadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? NotificationReadStatus.consentRequired
          : NotificationReadStatus.forbidden;
    }
    if (error.statusCode == 404) {
      return NotificationReadStatus.unavailable;
    }
    if (error.statusCode == 429) {
      _startRateLimitTimer(error.retryAfter);
      return NotificationReadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? NotificationReadStatus.timeout
          : NotificationReadStatus.offline;
    }
    return NotificationReadStatus.failed;
  }

  Future<void> _handleAuthBoundary(Object error) async {
    if (error is! ApiException ||
        (error.statusCode != 401 && error.statusCode != 403) ||
        _authFailureNotified) {
      return;
    }
    _authFailureNotified = true;
    await onAuthFailure?.call(error);
  }

  void _startRateLimitTimer(Duration? retryAfter) {
    final duration = retryAfter ?? const Duration(seconds: 1);
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer(duration, () {
      _rateLimitTimer = null;
      _notify();
    });
  }

  String _messageFor(Object error) {
    if (error is TokenStorageException) {
      return 'Secure session storage is unavailable. Notifications cannot be loaded.';
    }
    if (error is ApiContractException) {
      return 'The notification response does not match the documented API contract (${error.field}). Retry after confirming the API response.';
    }
    if (error is! ApiException) {
      return 'Notifications could not be loaded. Please retry.';
    }
    if (error.statusCode == 401) {
      return 'Your session is no longer valid. Please sign in again.';
    }
    if (error.statusCode == 403 && error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current policies before viewing notifications.';
    }
    if (error.statusCode == 403) {
      return 'Your Courier account is not currently allowed to view notifications.';
    }
    if (error.statusCode == 404) {
      return 'This notification is no longer available.';
    }
    if (error.statusCode == 422) {
      return 'The notification request was invalid. Refresh and retry.';
    }
    if (error.statusCode == 429) {
      final seconds =
          (error.retryAfter ?? const Duration(seconds: 1)).inSeconds;
      return seconds <= 1
          ? 'Too many notification requests. Try again in a moment.'
          : 'Too many notification requests. Try again in $seconds seconds.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'The notification request timed out. Check your connection and retry.'
          : 'Notifications are unavailable offline. Reconnect and retry.';
    }
    return 'Notifications could not be loaded. Please retry.';
  }
}
