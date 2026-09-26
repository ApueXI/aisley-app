part of 'support_ticket_controller.dart';

extension SupportTicketControllerErrors on SupportTicketController {
  Future<void> _readFailure(Object error, {required bool list}) async {
    final hasData = list ? tickets.isNotEmpty : events.isNotEmpty;
    final status = _loadStatus(error);
    final effective = hasData && status == SupportTicketLoadStatus.failed
        ? SupportTicketLoadStatus.stale
        : status;
    if (error is ApiException && error.statusCode == 404 && !list) {
      final id = activeTicketId;
      if (id != null) _removeTicket(id);
      activeTicket = null;
      events = const <SupportTicketEvent>[];
      nextEventCursor = null;
    }
    if (list) {
      listStatus = effective;
      listError = _errorMessage(error, subject: 'Support tickets');
    } else {
      detailStatus = effective;
      detailError = _errorMessage(error, subject: 'This support ticket');
    }
    await _authorizationBoundary(error);
    _notify();
  }

  Future<void> _mutationFailure(
    Object error, {
    required bool create,
    String? ticketId,
  }) async {
    final status = _mutationStatus(error);
    if (create) {
      createStatus = status;
      createError = _errorMessage(error, subject: 'The ticket request');
      if (status == SupportTicketMutationStatus.validation ||
          status == SupportTicketMutationStatus.conflict ||
          status == SupportTicketMutationStatus.failed) {
        pendingCreate = null;
      }
    } else if (ticketId != null) {
      replyStatuses[ticketId] = status;
      replyErrors[ticketId] = _errorMessage(error, subject: 'The reply');
      if (status == SupportTicketMutationStatus.validation ||
          status == SupportTicketMutationStatus.conflict ||
          status == SupportTicketMutationStatus.failed) {
        pendingReplies.remove(ticketId);
      }
      if (status == SupportTicketMutationStatus.conflict &&
          activeTicketId == ticketId) {
        unawaited(refreshDetail());
      }
    }
    await _authorizationBoundary(error);
    _notify();
  }

  Future<void> _readMutationFailure(String ticketId, Object error) async {
    final status = switch (error) {
      ApiException(statusCode: 422) => SupportTicketReadStatus.validation,
      ApiException(statusCode: 429) => SupportTicketReadStatus.rateLimited,
      ApiException(
        statusCode: null,
        networkFailure: ApiNetworkFailure.timeout,
      ) =>
        SupportTicketReadStatus.timeout,
      ApiException(statusCode: null) => SupportTicketReadStatus.offline,
      _ => SupportTicketReadStatus.failed,
    };
    if (error is ApiException && error.statusCode == 429) {
      _startRateLimit(error.retryAfter);
    }
    readStatuses[ticketId] = status;
    readErrors[ticketId] = _errorMessage(error, subject: 'The read marker');
    await _authorizationBoundary(error);
    _notify();
  }

  SupportTicketLoadStatus _loadStatus(Object error) {
    if (error is TokenStorageException) {
      return SupportTicketLoadStatus.secureStorageFailure;
    }
    if (error is ApiContractException) return SupportTicketLoadStatus.failed;
    if (error is! ApiException) return SupportTicketLoadStatus.failed;
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? SupportTicketLoadStatus.consentRequired
          : SupportTicketLoadStatus.forbidden;
    }
    if (error.statusCode == 404) return SupportTicketLoadStatus.unavailable;
    if (error.statusCode == 429) {
      _startRateLimit(error.retryAfter);
      return SupportTicketLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? SupportTicketLoadStatus.timeout
          : SupportTicketLoadStatus.offline;
    }
    return SupportTicketLoadStatus.failed;
  }

  SupportTicketMutationStatus _mutationStatus(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 422) {
        return SupportTicketMutationStatus.validation;
      }
      if (error.statusCode == 409) return SupportTicketMutationStatus.conflict;
      if (error.statusCode == 429) {
        _startRateLimit(error.retryAfter);
        return SupportTicketMutationStatus.rateLimited;
      }
      if (error.isNetworkError ||
          (error.statusCode != null && error.statusCode! >= 500)) {
        return SupportTicketMutationStatus.uncertain;
      }
      return SupportTicketMutationStatus.failed;
    }
    if (error is ApiContractException) {
      return SupportTicketMutationStatus.uncertain;
    }
    return SupportTicketMutationStatus.failed;
  }

  Future<void> _authorizationBoundary(Object error) async {
    if (error is TokenStorageException) {
      clear();
      listStatus = SupportTicketLoadStatus.secureStorageFailure;
      listError = 'Secure session storage is unavailable.';
      _notify();
      return;
    }
    if (error is! ApiException ||
        (error.statusCode != 401 && error.statusCode != 403)) {
      return;
    }
    clear();
    await onAuthFailure?.call(error);
  }

  void _startRateLimit(Duration? retryAfter) {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer(retryAfter ?? const Duration(seconds: 1), () {
      _rateLimitTimer = null;
      _notify();
    });
  }

  String _errorMessage(Object error, {required String subject}) {
    if (error is TokenStorageException) {
      return 'Secure session storage is unavailable.';
    }
    if (error is ApiContractException) {
      return '$subject response did not match the documented API contract (${error.field}).';
    }
    if (error is! ApiException) return '$subject could not be completed.';
    if (error.statusCode == 401) {
      return 'Your session is no longer valid. Please sign in again.';
    }
    if (error.statusCode == 403 && error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current policies before using support tickets.';
    }
    if (error.statusCode == 403) {
      return 'Your Courier account cannot use support tickets right now.';
    }
    if (error.statusCode == 404) {
      return 'This support ticket is no longer available.';
    }
    if (error.statusCode == 409) {
      return 'The ticket changed. The latest history was requested; review it before retrying.';
    }
    if (error.statusCode == 422) {
      final messages = error.fieldErrors.values.expand((value) => value);
      return messages.isEmpty
          ? 'Check the entered ticket information and retry.'
          : messages.join(' ');
    }
    if (error.statusCode == 429) {
      return 'Too many support requests. Wait before retrying the same request.';
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? '$subject timed out. Its outcome is not confirmed.'
          : '$subject is unavailable offline. Reconnect before retrying.';
    }
    if (error.statusCode != null && error.statusCode! >= 500) {
      return '$subject may not have completed. Retry the exact same request.';
    }
    return '$subject could not be completed.';
  }
}
