part of 'support_ticket_controller.dart';

extension SupportTicketControllerReads on SupportTicketController {
  Future<void> refreshList({bool silent = false}) async {
    if (!canRetry) return;
    final scope = _scopeEpoch;
    final request = ++_listRequest;
    loadingMoreTickets = false;
    if (!silent || tickets.isEmpty) {
      listStatus = SupportTicketLoadStatus.loading;
    }
    listError = null;
    loadMoreError = null;
    _notify();
    try {
      final page = await repository.list(
        status: statusFilter,
        category: categoryFilter,
        limit: 20,
      );
      if (scope != _scopeEpoch || request != _listRequest) return;
      tickets = List<SupportTicketSummary>.unmodifiable(
        page.items.take(SupportTicketController.maxInMemoryTickets),
      );
      nextTicketCursor = page.nextCursor;
      listStatus = tickets.isEmpty
          ? SupportTicketLoadStatus.empty
          : SupportTicketLoadStatus.loaded;
      _notify();
    } catch (error) {
      if (scope != _scopeEpoch || request != _listRequest) return;
      await _readFailure(error, list: true);
    }
  }

  Future<void> loadMoreTicketsPage() async {
    final cursor = nextTicketCursor;
    if (cursor == null || loadingMoreTickets || !canRetry) return;
    final scope = _scopeEpoch;
    final request = _listRequest;
    loadingMoreTickets = true;
    loadMoreError = null;
    _notify();
    try {
      final page = await repository.list(
        status: statusFilter,
        category: categoryFilter,
        cursor: cursor,
        limit: 20,
      );
      if (scope != _scopeEpoch || request != _listRequest) return;
      final byId = <String, SupportTicketSummary>{
        for (final ticket in tickets) ticket.id: ticket,
      };
      for (final ticket in page.items) {
        byId[ticket.id] = ticket;
      }
      tickets = List<SupportTicketSummary>.unmodifiable(
        byId.values.take(SupportTicketController.maxInMemoryTickets),
      );
      nextTicketCursor = page.nextCursor;
      loadingMoreTickets = false;
      listStatus = SupportTicketLoadStatus.loaded;
      _notify();
    } catch (error) {
      if (scope != _scopeEpoch || request != _listRequest) return;
      loadingMoreTickets = false;
      loadMoreError = _errorMessage(error, subject: 'Support tickets');
      await _authorizationBoundary(error);
      _notify();
    }
  }

  Future<void> setFilters({
    SupportTicketStatusFilter? status,
    SupportTicketCategoryFilter? category,
  }) async {
    final nextStatus = status ?? statusFilter;
    final nextCategory = category ?? categoryFilter;
    if (nextStatus == statusFilter && nextCategory == categoryFilter) return;
    statusFilter = nextStatus;
    categoryFilter = nextCategory;
    tickets = const <SupportTicketSummary>[];
    nextTicketCursor = null;
    await refreshList();
  }

  Future<void> openDetail(SupportTicketSummary ticket) async {
    _detailRequest++;
    activeTicketId = ticket.id;
    activeTicket = ticket;
    events = const <SupportTicketEvent>[];
    nextEventCursor = null;
    detailStatus = SupportTicketLoadStatus.loading;
    detailError = null;
    loadingMoreEvents = false;
    _notify();
    await refreshDetail();
  }

  Future<void> refreshDetail({bool silent = false}) async {
    final ticketId = activeTicketId;
    if (ticketId == null || !canRetry) return;
    final scope = _scopeEpoch;
    final request = ++_detailRequest;
    if (!silent || events.isEmpty) {
      detailStatus = SupportTicketLoadStatus.loading;
    }
    detailError = null;
    _notify();
    try {
      final page = await repository.detail(ticketId, limit: 20);
      if (scope != _scopeEpoch ||
          request != _detailRequest ||
          activeTicketId != ticketId) {
        return;
      }
      if (page.ticket.id != ticketId) {
        throw const ApiContractException('support.detail.id');
      }
      final mergedTicket = page.ticket.mergeWith(
        activeTicket ?? ticketById(ticketId),
      );
      activeTicket = mergedTicket;
      _replaceTicket(mergedTicket);
      _mergeEvents(page.events, replace: !silent && events.isEmpty);
      nextEventCursor = page.nextCursor;
      detailStatus = SupportTicketLoadStatus.loaded;
      _notify();
    } catch (error) {
      if (scope != _scopeEpoch || request != _detailRequest) return;
      await _readFailure(error, list: false);
    }
  }

  Future<void> loadOlderEvents() async {
    final ticketId = activeTicketId;
    final cursor = nextEventCursor;
    if (ticketId == null || cursor == null || loadingMoreEvents || !canRetry) {
      return;
    }
    final scope = _scopeEpoch;
    final request = _detailRequest;
    loadingMoreEvents = true;
    detailError = null;
    _notify();
    try {
      final page = await repository.detail(ticketId, cursor: cursor, limit: 20);
      if (scope != _scopeEpoch ||
          request != _detailRequest ||
          activeTicketId != ticketId) {
        return;
      }
      if (page.ticket.id != ticketId) {
        throw const ApiContractException('support.detail.id');
      }
      final mergedTicket = page.ticket.mergeWith(activeTicket);
      activeTicket = mergedTicket;
      _replaceTicket(mergedTicket);
      _mergeEvents(page.events);
      nextEventCursor = page.nextCursor;
      loadingMoreEvents = false;
      detailStatus = SupportTicketLoadStatus.loaded;
      _notify();
    } catch (error) {
      if (scope != _scopeEpoch || request != _detailRequest) return;
      loadingMoreEvents = false;
      detailError = _errorMessage(error, subject: 'Older ticket updates');
      await _authorizationBoundary(error);
      _notify();
    }
  }

  void closeDetail() {
    _detailRequest++;
    activeTicketId = null;
    activeTicket = null;
    events = const <SupportTicketEvent>[];
    nextEventCursor = null;
    detailStatus = SupportTicketLoadStatus.idle;
    detailError = null;
    loadingMoreEvents = false;
    _notify();
  }

  void _mergeEvents(List<SupportTicketEvent> incoming, {bool replace = false}) {
    final byId = <String, SupportTicketEvent>{
      if (!replace)
        for (final event in events) event.id: event,
    };
    final sequenceOwners = <int, String>{
      if (!replace)
        for (final event in events) event.sequence: event.id,
    };
    for (final event in incoming) {
      final existingId = sequenceOwners[event.sequence];
      if (existingId != null && existingId != event.id) {
        throw const ApiContractException('support.event.sequence');
      }
      byId[event.id] = event;
      sequenceOwners[event.sequence] = event.id;
    }
    final sorted = byId.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    events = List<SupportTicketEvent>.unmodifiable(
      sorted.length > SupportTicketController.maxInMemoryEvents
          ? sorted.sublist(
              sorted.length - SupportTicketController.maxInMemoryEvents,
            )
          : sorted,
    );
  }
}
