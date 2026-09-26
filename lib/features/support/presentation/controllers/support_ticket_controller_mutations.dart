part of 'support_ticket_controller.dart';

extension SupportTicketControllerMutations on SupportTicketController {
  Future<SupportTicketSummary?> createTicket({
    required String subject,
    required String category,
    required String body,
  }) async {
    final normalizedSubject = subject.trim();
    final normalizedBody = body.trim();
    updateCreateDraft(subject: subject, category: category, body: body);
    if (normalizedSubject.isEmpty ||
        normalizedSubject.length > 150 ||
        !supportTicketCategories.contains(category) ||
        normalizedBody.isEmpty ||
        normalizedBody.length > 2000) {
      createStatus = SupportTicketMutationStatus.validation;
      createError = 'Enter a subject of 1–150 characters, choose a category, and enter a message of 1–2,000 characters.';
      _notify();
      return null;
    }
    if (!canRetry || createStatus == SupportTicketMutationStatus.submitting) {
      return null;
    }
    var attempt = pendingCreate;
    if (attempt != null &&
        (attempt.subject != normalizedSubject ||
            attempt.category != category ||
            attempt.body != normalizedBody)) {
      createStatus = SupportTicketMutationStatus.uncertain;
      createError = 'Retry the same ticket request, or discard the pending retry before changing it.';
      _notify();
      return null;
    }
    attempt ??= SupportTicketCreateAttempt(
      subject: normalizedSubject,
      category: category,
      body: normalizedBody,
      key: SupportTicketController._newUuid(),
    );
    pendingCreate = attempt;
    createStatus = SupportTicketMutationStatus.submitting;
    createError = null;
    _notify();
    final scope = _scopeEpoch;
    try {
      final result = await repository.create(
        subject: attempt.subject,
        category: attempt.category,
        body: attempt.body,
        idempotencyKey: attempt.key,
      );
      if (scope != _scopeEpoch) return null;
      _validateMutation(result);
      pendingCreate = null;
      createStatus = SupportTicketMutationStatus.saved;
      createError = null;
      createSubjectDraft = '';
      createCategoryDraft = 'general';
      createBodyDraft = '';
      _replaceTicket(result.ticket);
      activeTicketId = result.ticket.id;
      activeTicket = result.ticket;
      events = <SupportTicketEvent>[result.event];
      nextEventCursor = null;
      detailStatus = SupportTicketLoadStatus.loaded;
      _notify();
      return result.ticket;
    } catch (error) {
      if (scope != _scopeEpoch) return null;
      await _mutationFailure(error, create: true);
      return null;
    }
  }

  Future<bool> reply(String ticketId, String body) async {
    final ticket = activeTicketId == ticketId
        ? activeTicket
        : ticketById(ticketId);
    final normalizedBody = body.trim();
    updateReplyDraft(ticketId, body);
    if (ticket == null ||
        ticket.revision < 1 ||
        normalizedBody.isEmpty ||
        normalizedBody.length > 2000) {
      replyStatuses[ticketId] = SupportTicketMutationStatus.validation;
      replyErrors[ticketId] =
          'Enter a reply of 1–2,000 characters after the ticket has loaded.';
      _notify();
      return false;
    }
    if (!canRetry ||
        replyStatusFor(ticketId) == SupportTicketMutationStatus.submitting) {
      return false;
    }
    var attempt = pendingReplies[ticketId];
    if (attempt != null && attempt.body != normalizedBody) {
      replyStatuses[ticketId] = SupportTicketMutationStatus.uncertain;
      replyErrors[ticketId] = 'Retry the same reply, or discard the pending retry before changing it.';
      _notify();
      return false;
    }
    attempt ??= SupportTicketReplyAttempt(
      ticketId: ticketId,
      body: normalizedBody,
      expectedRevision: ticket.revision,
      key: SupportTicketController._newUuid(),
    );
    pendingReplies[ticketId] = attempt;
    replyStatuses[ticketId] = SupportTicketMutationStatus.submitting;
    replyErrors[ticketId] = null;
    _notify();
    final scope = _scopeEpoch;
    try {
      final result = await repository.reply(
        ticketId: ticketId,
        body: attempt.body,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.key,
      );
      if (scope != _scopeEpoch) return false;
      _validateMutation(result, expectedTicketId: ticketId);
      pendingReplies.remove(ticketId);
      replyDrafts.remove(ticketId);
      replyStatuses[ticketId] = SupportTicketMutationStatus.saved;
      replyErrors[ticketId] = null;
      _replaceTicket(result.ticket);
      if (activeTicketId == ticketId) {
        activeTicket = result.ticket;
        _mergeEvents(<SupportTicketEvent>[result.event]);
        detailStatus = SupportTicketLoadStatus.loaded;
      }
      _notify();
      return true;
    } catch (error) {
      if (scope != _scopeEpoch) return false;
      await _mutationFailure(error, create: false, ticketId: ticketId);
      return false;
    }
  }

  Future<bool> markRead(String ticketId) async {
    final ticket = activeTicketId == ticketId
        ? activeTicket
        : ticketById(ticketId);
    final sequence = latestVisibleSequence;
    if (ticket == null || sequence == null) {
      readStatuses[ticketId] = SupportTicketReadStatus.validation;
      readErrors[ticketId] = 'Load the ticket history before marking it read.';
      _notify();
      return false;
    }
    if (ticket.unreadCount == 0) return true;
    if (!canRetry ||
        readStatusFor(ticketId) == SupportTicketReadStatus.submitting) {
      return false;
    }
    readStatuses[ticketId] = SupportTicketReadStatus.submitting;
    readErrors[ticketId] = null;
    _notify();
    final scope = _scopeEpoch;
    try {
      final updated = await repository.markRead(
        ticketId: ticketId,
        lastReadSequence: sequence,
      );
      if (scope != _scopeEpoch) return false;
      if (updated.id != ticketId) {
        throw const ApiContractException('support.read.id');
      }
      _replaceTicket(updated);
      readStatuses[ticketId] = SupportTicketReadStatus.saved;
      readErrors[ticketId] = null;
      _notify();
      return true;
    } catch (error) {
      if (scope != _scopeEpoch) return false;
      await _readMutationFailure(ticketId, error);
      return false;
    }
  }

  void discardPendingCreate() {
    pendingCreate = null;
    createStatus = SupportTicketMutationStatus.idle;
    createError = null;
    _notify();
  }

  void discardPendingReply(String ticketId) {
    pendingReplies.remove(ticketId);
    replyStatuses[ticketId] = SupportTicketMutationStatus.idle;
    replyErrors[ticketId] = null;
    _notify();
  }

  void _validateMutation(
    SupportTicketMutation result, {
    String? expectedTicketId,
  }) {
    if (expectedTicketId != null && result.ticket.id != expectedTicketId) {
      throw const ApiContractException('support.mutation.id');
    }
    if (result.event.sequence < 1) {
      throw const ApiContractException('support.mutation.sequence');
    }
  }
}
