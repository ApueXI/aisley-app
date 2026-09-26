import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/support/data/support_ticket_repository.dart';
import 'package:aisley_app/features/support/domain/support_ticket_models.dart';
import 'package:aisley_app/features/support/presentation/controllers/support_ticket_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads filters and appends a deduplicated cursor page', () async {
    final repository = _SupportRepository()
      ..listPages.add(SupportTicketPage(items: [_ticket()], nextCursor: 'next'))
      ..listPages.add(
        SupportTicketPage(
          items: [
            _ticket(revision: 2),
            _ticket(id: 'ticket-2'),
          ],
          nextCursor: null,
        ),
      );
    final controller = SupportTicketController(repository: repository);

    await controller.setFilters(
      status: SupportTicketStatusFilter.open,
      category: SupportTicketCategoryFilter.delivery,
    );
    await controller.loadMoreTicketsPage();

    expect(repository.statuses, [
      SupportTicketStatusFilter.open,
      SupportTicketStatusFilter.open,
    ]);
    expect(repository.categories, [
      SupportTicketCategoryFilter.delivery,
      SupportTicketCategoryFilter.delivery,
    ]);
    expect(repository.cursors, [null, 'next']);
    expect(controller.tickets, hasLength(2));
    expect(controller.ticketById('ticket-1')?.revision, 2);
    controller.dispose();
  });

  test('timeout preserves exact create draft and UUID for retry', () async {
    final repository = _SupportRepository()..failFirstCreate = true;
    final controller = SupportTicketController(repository: repository);

    expect(
      await controller.createTicket(
        subject: ' Task help ',
        category: 'delivery',
        body: ' Please help ',
      ),
      isNull,
    );
    final key = controller.pendingCreate!.key;
    expect(controller.createStatus, SupportTicketMutationStatus.uncertain);
    expect(controller.createSubjectDraft, ' Task help ');
    expect(
      await controller.createTicket(
        subject: 'Changed',
        category: 'delivery',
        body: 'Please help',
      ),
      isNull,
    );
    expect(repository.createKeys, [key]);

    final saved = await controller.createTicket(
      subject: 'Task help',
      category: 'delivery',
      body: 'Please help',
    );
    expect(saved?.id, 'ticket-1');
    expect(repository.createKeys, [key, key]);
    expect(controller.pendingCreate, isNull);
    controller.dispose();
  });

  test(
    'reply uses current revision and keeps exact retry after timeout',
    () async {
      final repository = _SupportRepository()..failFirstReply = true;
      final controller = SupportTicketController(repository: repository);
      await controller.openDetail(_ticket(revision: 7));

      expect(await controller.reply('ticket-1', ' More details '), isFalse);
      final attempt = controller.pendingReplyFor('ticket-1')!;
      expect(attempt.expectedRevision, 7);
      expect(controller.replyDraftFor('ticket-1'), ' More details ');

      expect(await controller.reply('ticket-1', 'More details'), isTrue);
      expect(repository.replyKeys, [attempt.key, attempt.key]);
      expect(repository.replyRevisions, [7, 7]);
      expect(controller.pendingReplyFor('ticket-1'), isNull);
      expect(controller.events.last.body, 'More details');
      controller.dispose();
    },
  );

  test(
    'stale revision preserves draft, refetches, and releases old key',
    () async {
      final repository = _SupportRepository()
        ..replyError = const ApiException(
          statusCode: 409,
          code: 'CONFLICT',
          message: 'private detail',
        );
      final controller = SupportTicketController(repository: repository);
      await controller.openDetail(_ticket(revision: 4));

      expect(await controller.reply('ticket-1', 'Keep this draft'), isFalse);
      await Future<void>.delayed(Duration.zero);

      expect(controller.replyDraftFor('ticket-1'), 'Keep this draft');
      expect(controller.pendingReplyFor('ticket-1'), isNull);
      expect(repository.detailCalls, greaterThanOrEqualTo(2));
      controller.dispose();
    },
  );

  test(
    'mark read sends latest visible sequence without an optimistic clear',
    () async {
      final repository = _SupportRepository();
      final controller = SupportTicketController(repository: repository);
      await controller.openDetail(_ticket(unreadCount: 2));

      expect(await controller.markRead('ticket-1'), isTrue);

      expect(repository.readSequences, [2]);
      expect(controller.activeTicket?.unreadCount, 0);
      controller.dispose();
    },
  );

  test(
    'offline write stays unsent and private state clears on logout',
    () async {
      final repository = _SupportRepository()
        ..createError = const ApiException.network('private offline');
      final controller = SupportTicketController(repository: repository);

      await controller.createTicket(
        subject: 'Account issue',
        category: 'account',
        body: 'Please help',
      );
      expect(controller.tickets, isEmpty);
      expect(controller.pendingCreate, isNotNull);
      expect(controller.createError, isNot(contains('private')));

      controller.clear();
      expect(controller.pendingCreate, isNull);
      expect(controller.createBodyDraft, isEmpty);
      expect(controller.tickets, isEmpty);
      expect(controller.events, isEmpty);
      expect(controller.isPolling, isFalse);
      controller.dispose();
    },
  );

  test(
    '401 clears private state and hands control to authentication',
    () async {
      final repository = _SupportRepository()
        ..listError = const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'private detail',
        );
      var authCalled = false;
      final controller = SupportTicketController(
        repository: repository,
        onAuthFailure: (error) async => authCalled = error.statusCode == 401,
      );

      await controller.refreshList();

      expect(authCalled, isTrue);
      expect(controller.tickets, isEmpty);
      expect(controller.pendingCreate, isNull);
      controller.dispose();
    },
  );

  test('policy denial clears state and hands off to consent', () async {
    final repository = _SupportRepository()
      ..listError = const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: 'private detail',
      );
    var consentCalled = false;
    final controller = SupportTicketController(
      repository: repository,
      onAuthFailure: (error) async {
        consentCalled = error.code == 'POLICY_CONSENT_REQUIRED';
      },
    );

    await controller.refreshList();

    expect(consentCalled, isTrue);
    expect(controller.tickets, isEmpty);
    controller.dispose();
  });

  test('422 releases rejected key but preserves editable draft', () async {
    final repository = _SupportRepository()
      ..createError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_FAILED',
        message: 'private detail',
        fieldErrors: {
          'subject': ['Enter a valid subject.'],
        },
      );
    final controller = SupportTicketController(repository: repository);

    await controller.createTicket(
      subject: 'Account issue',
      category: 'account',
      body: 'Please help',
    );

    expect(controller.createStatus, SupportTicketMutationStatus.validation);
    expect(controller.pendingCreate, isNull);
    expect(controller.createSubjectDraft, 'Account issue');
    expect(controller.createError, 'Enter a valid subject.');
    controller.dispose();
  });

  test('429 preserves exact attempt and enforces retry-after', () async {
    final repository = _SupportRepository()
      ..createError = const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'private detail',
        retryAfter: Duration(milliseconds: 30),
      );
    final controller = SupportTicketController(repository: repository);

    await controller.createTicket(
      subject: 'Account issue',
      category: 'account',
      body: 'Please help',
    );

    expect(controller.pendingCreate, isNotNull);
    expect(controller.createStatus, SupportTicketMutationStatus.rateLimited);
    expect(controller.canRetry, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.canRetry, isTrue);
    controller.dispose();
  });

  test('scoped 404 removes stale detail and becomes unavailable', () async {
    final repository = _SupportRepository()
      ..detailError = const ApiException(
        statusCode: 404,
        code: 'NOT_FOUND',
        message: 'private detail',
      );
    final controller = SupportTicketController(repository: repository);

    await controller.openDetail(_ticket());

    expect(controller.activeTicket, isNull);
    expect(controller.events, isEmpty);
    expect(controller.detailStatus, SupportTicketLoadStatus.unavailable);
    controller.dispose();
  });

  test('polling runs only between explicit visible start and stop', () {
    final controller = SupportTicketController(
      repository: _SupportRepository(),
    );

    expect(controller.isPolling, isFalse);
    controller.startListPolling(refreshImmediately: false);
    expect(controller.isPolling, isTrue);
    controller.stopPolling();
    expect(controller.isPolling, isFalse);
    controller.dispose();
  });
}

class _SupportRepository implements SupportTicketRepository {
  final List<SupportTicketPage> listPages = [];
  final List<SupportTicketStatusFilter> statuses = [];
  final List<SupportTicketCategoryFilter> categories = [];
  final List<String?> cursors = [];
  final List<String> createKeys = [];
  final List<String> replyKeys = [];
  final List<int> replyRevisions = [];
  final List<int> readSequences = [];
  bool failFirstCreate = false;
  bool failFirstReply = false;
  Object? listError;
  Object? createError;
  Object? replyError;
  Object? detailError;
  int detailCalls = 0;

  @override
  Future<SupportTicketPage> list({
    SupportTicketStatusFilter status = SupportTicketStatusFilter.all,
    SupportTicketCategoryFilter category = SupportTicketCategoryFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    statuses.add(status);
    categories.add(category);
    cursors.add(cursor);
    if (listError case final error?) throw error;
    return listPages.isEmpty
        ? const SupportTicketPage(items: [], nextCursor: null)
        : listPages.removeAt(0);
  }

  @override
  Future<SupportTicketMutation> create({
    required String subject,
    required String category,
    required String body,
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    if (createError case final error?) throw error;
    if (failFirstCreate) {
      failFirstCreate = false;
      throw const ApiException.network(
        'private timeout',
        networkFailure: ApiNetworkFailure.timeout,
      );
    }
    return SupportTicketMutation(
      ticket: _ticket(subject: subject, category: category),
      event: _event(sequence: 1, body: body),
    );
  }

  @override
  Future<SupportTicketDetailPage> detail(
    String ticketId, {
    String? cursor,
    int limit = 20,
  }) async {
    detailCalls++;
    if (detailError case final error?) throw error;
    return SupportTicketDetailPage(
      ticket: SupportTicketDetailRecord(
        id: ticketId,
        reference: 'SUP-0001',
        status: 'open',
        revision: 7,
      ),
      events: [
        _event(sequence: 1),
        _event(id: 'event-2', sequence: 2),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<SupportTicketMutation> reply({
    required String ticketId,
    required String body,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    replyKeys.add(idempotencyKey);
    replyRevisions.add(expectedRevision);
    if (replyError case final error?) throw error;
    if (failFirstReply) {
      failFirstReply = false;
      throw const ApiException.network(
        'private timeout',
        networkFailure: ApiNetworkFailure.timeout,
      );
    }
    return SupportTicketMutation(
      ticket: _ticket(id: ticketId, revision: expectedRevision + 1),
      event: _event(id: 'event-3', sequence: 3, body: body),
    );
  }

  @override
  Future<SupportTicketSummary> markRead({
    required String ticketId,
    required int lastReadSequence,
  }) async {
    readSequences.add(lastReadSequence);
    return _ticket(id: ticketId, revision: 7, unreadCount: 0);
  }
}

SupportTicketSummary _ticket({
  String id = 'ticket-1',
  String subject = 'Task help',
  String category = 'delivery',
  int revision = 1,
  int unreadCount = 0,
}) {
  return SupportTicketSummary(
    id: id,
    reference: id == 'ticket-1' ? 'SUP-0001' : 'SUP-0002',
    subject: subject,
    category: category,
    status: 'open',
    revision: revision,
    requesterRole: 'courier',
    unreadCount: unreadCount,
  );
}

SupportTicketEvent _event({
  String id = 'event-1',
  required int sequence,
  String body = 'Initial message',
}) {
  return SupportTicketEvent(
    id: id,
    sequence: sequence,
    type: 'reply',
    actorRole: 'courier',
    isMine: true,
    assignmentChanged: false,
    body: body,
  );
}
