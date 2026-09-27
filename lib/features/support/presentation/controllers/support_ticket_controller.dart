import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../data/support_ticket_repository.dart';
import '../../domain/support_ticket_models.dart';

part 'support_ticket_controller_reads.dart';
part 'support_ticket_controller_mutations.dart';
part 'support_ticket_controller_errors.dart';

typedef SupportTicketAuthFailureHandler = Future<void> Function(
  ApiException error,
);

enum SupportTicketLoadStatus {
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
  secureStorageFailure,
}

enum SupportTicketMutationStatus {
  idle,
  submitting,
  saved,
  validation,
  conflict,
  uncertain,
  rateLimited,
  failed,
}

enum SupportTicketReadStatus {
  idle,
  submitting,
  saved,
  validation,
  offline,
  timeout,
  rateLimited,
  failed,
}

class SupportTicketCreateAttempt {
  const SupportTicketCreateAttempt({
    required this.subject,
    required this.category,
    required this.body,
    required this.key,
  });

  final String subject;
  final String category;
  final String body;
  final String key;
}

class SupportTicketReplyAttempt {
  const SupportTicketReplyAttempt({
    required this.ticketId,
    required this.body,
    required this.expectedRevision,
    required this.key,
  });

  final String ticketId;
  final String body;
  final int expectedRevision;
  final String key;
}

class SupportTicketController extends ChangeNotifier {
  SupportTicketController({required this.repository, this.onAuthFailure});

  static const pollInterval = Duration(seconds: 30);
  static const maxInMemoryTickets = 100;
  static const maxInMemoryEvents = 200;

  final SupportTicketRepository repository;
  final SupportTicketAuthFailureHandler? onAuthFailure;

  SupportTicketStatusFilter statusFilter = SupportTicketStatusFilter.all;
  SupportTicketCategoryFilter categoryFilter = SupportTicketCategoryFilter.all;
  SupportTicketLoadStatus listStatus = SupportTicketLoadStatus.idle;
  List<SupportTicketSummary> tickets = const <SupportTicketSummary>[];
  String? nextTicketCursor;
  String? listError;
  String? loadMoreError;
  bool loadingMoreTickets = false;

  String? activeTicketId;
  SupportTicketSummary? activeTicket;
  List<SupportTicketEvent> events = const <SupportTicketEvent>[];
  String? nextEventCursor;
  SupportTicketLoadStatus detailStatus = SupportTicketLoadStatus.idle;
  String? detailError;
  bool loadingMoreEvents = false;

  String createSubjectDraft = '';
  String createCategoryDraft = 'general';
  String createBodyDraft = '';
  SupportTicketCreateAttempt? pendingCreate;
  SupportTicketMutationStatus createStatus = SupportTicketMutationStatus.idle;
  String? createError;

  final Map<String, String> replyDrafts = <String, String>{};
  final Map<String, SupportTicketReplyAttempt> pendingReplies =
      <String, SupportTicketReplyAttempt>{};
  final Map<String, SupportTicketMutationStatus> replyStatuses =
      <String, SupportTicketMutationStatus>{};
  final Map<String, String?> replyErrors = <String, String?>{};
  final Map<String, SupportTicketReadStatus> readStatuses =
      <String, SupportTicketReadStatus>{};
  final Map<String, String?> readErrors = <String, String?>{};

  int _scopeEpoch = 0;
  int _listRequest = 0;
  int _detailRequest = 0;
  Timer? _pollTimer;
  Timer? _rateLimitTimer;
  bool _disposed = false;

  bool get canRetry => _rateLimitTimer == null;
  bool get isPolling => _pollTimer != null;
  bool get canLoadMoreTickets =>
      nextTicketCursor != null && !loadingMoreTickets && canRetry;
  bool get canLoadMoreEvents =>
      nextEventCursor != null && !loadingMoreEvents && canRetry;
  int? get latestVisibleSequence =>
      events.isEmpty ? null : events.last.sequence;

  SupportTicketSummary? ticketById(String id) {
    for (final ticket in tickets) {
      if (ticket.id == id) return ticket;
    }
    return null;
  }

  String replyDraftFor(String ticketId) => replyDrafts[ticketId] ?? '';
  SupportTicketReplyAttempt? pendingReplyFor(String ticketId) =>
      pendingReplies[ticketId];
  SupportTicketMutationStatus replyStatusFor(String ticketId) =>
      replyStatuses[ticketId] ?? SupportTicketMutationStatus.idle;
  String? replyErrorFor(String ticketId) => replyErrors[ticketId];
  SupportTicketReadStatus readStatusFor(String ticketId) =>
      readStatuses[ticketId] ?? SupportTicketReadStatus.idle;
  String? readErrorFor(String ticketId) => readErrors[ticketId];

  void updateCreateDraft({String? subject, String? category, String? body}) {
    if (subject != null) createSubjectDraft = subject;
    if (category != null) createCategoryDraft = category;
    if (body != null) createBodyDraft = body;
  }

  void updateReplyDraft(String ticketId, String body) {
    replyDrafts[ticketId] = body;
  }

  void startListPolling({bool refreshImmediately = true}) {
    stopPolling();
    if (refreshImmediately) unawaited(refreshList());
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(refreshList(silent: true));
    });
  }

  void startDetailPolling(String ticketId, {bool refreshImmediately = false}) {
    stopPolling();
    if (refreshImmediately) unawaited(refreshDetail());
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (activeTicketId == ticketId) {
        unawaited(refreshDetail(silent: true));
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clear() {
    _scopeEpoch++;
    _listRequest++;
    _detailRequest++;
    stopPolling();
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    statusFilter = SupportTicketStatusFilter.all;
    categoryFilter = SupportTicketCategoryFilter.all;
    listStatus = SupportTicketLoadStatus.idle;
    tickets = const <SupportTicketSummary>[];
    nextTicketCursor = null;
    listError = null;
    loadMoreError = null;
    loadingMoreTickets = false;
    activeTicketId = null;
    activeTicket = null;
    events = const <SupportTicketEvent>[];
    nextEventCursor = null;
    detailStatus = SupportTicketLoadStatus.idle;
    detailError = null;
    loadingMoreEvents = false;
    createSubjectDraft = '';
    createCategoryDraft = 'general';
    createBodyDraft = '';
    pendingCreate = null;
    createStatus = SupportTicketMutationStatus.idle;
    createError = null;
    replyDrafts.clear();
    pendingReplies.clear();
    replyStatuses.clear();
    replyErrors.clear();
    readStatuses.clear();
    readErrors.clear();
    _notify();
  }

  void _replaceTicket(SupportTicketSummary ticket, {bool addIfMissing = true}) {
    final updated = <SupportTicketSummary>[
      ticket,
      for (final item in tickets)
        if (item.id != ticket.id) item,
    ];
    if (!addIfMissing && !tickets.any((item) => item.id == ticket.id)) return;
    tickets = List<SupportTicketSummary>.unmodifiable(
      updated.take(maxInMemoryTickets),
    );
    if (activeTicketId == ticket.id) activeTicket = ticket;
  }

  void _removeTicket(String ticketId) {
    tickets = List<SupportTicketSummary>.unmodifiable(
      tickets.where((ticket) => ticket.id != ticketId),
    );
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    _rateLimitTimer?.cancel();
    super.dispose();
  }
}
