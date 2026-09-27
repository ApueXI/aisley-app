import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/support/data/support_ticket_repository.dart';
import 'package:aisley_app/features/support/domain/support_ticket_models.dart';
import 'package:aisley_app/features/support/presentation/controllers/support_ticket_controller.dart';
import 'package:aisley_app/features/support/presentation/support_ticket_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows empty, filters, and distinct support entry action', (
    tester,
  ) async {
    final repository = _WidgetSupportRepository();
    final controller = SupportTicketController(repository: repository);
    final auth = _authenticatedAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: SupportTicketScreen(controller: controller, authController: auth),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.text('No support tickets match these filters.'),
      findsOneWidget,
    );
    expect(find.text('Create support ticket'), findsOneWidget);
    expect(find.text('Task messages'), findsNothing);
    expect(
      find.byType(DropdownButtonFormField<SupportTicketStatusFilter>),
      findsOneWidget,
    );
    expect(
      find.byType(DropdownButtonFormField<SupportTicketCategoryFilter>),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

  testWidgets('creates a ticket only after the server confirms it', (
    tester,
  ) async {
    final repository = _WidgetSupportRepository();
    final controller = SupportTicketController(repository: repository);
    final auth = _authenticatedAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: SupportTicketScreen(controller: controller, authController: auth),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Create support ticket'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Account issue');
    await tester.enterText(fields.at(1), 'Please help with my account.');
    await tester.ensureVisible(find.text('Create ticket'));
    await tester.tap(find.text('Create ticket'));
    await tester.pumpAndSettle();

    expect(repository.createCount, 1);
    expect(find.text('SUP-0001'), findsWidgets);
    expect(find.text('Initial message'), findsOneWidget);
    expect(find.text('Send reply'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

  testWidgets('offline create exposes exact retry without claiming success', (
    tester,
  ) async {
    final repository = _WidgetSupportRepository()..offlineCreate = true;
    final controller = SupportTicketController(repository: repository);
    final auth = _authenticatedAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: SupportTicketScreen(controller: controller, authController: auth),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Create support ticket'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Delivery issue');
    await tester.enterText(fields.at(1), 'The task cannot be opened.');
    await tester.ensureVisible(find.text('Create ticket'));
    await tester.tap(find.text('Create ticket'));
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pump();

    expect(find.text('Retry same request'), findsOneWidget);
    expect(find.textContaining('unavailable offline'), findsOneWidget);
    expect(find.text('SUP-0001'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

  testWidgets('ticket cards expose an accessible unread label', (tester) async {
    final repository = _WidgetSupportRepository()..showTicket = true;
    final controller = SupportTicketController(repository: repository);
    final auth = _authenticatedAuth();
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: SupportTicketScreen(controller: controller, authController: auth),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.bySemanticsLabel(
        RegExp(r'SUP-0001.*Task help.*Open.*2 unread updates'),
      ),
      findsOneWidget,
    );

    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

  testWidgets('detail orders events and marks the latest sequence read', (
    tester,
  ) async {
    final repository = _WidgetSupportRepository()
      ..detailEvents = [
        _event(id: 'event-2', sequence: 2, body: 'Second update'),
        _event(sequence: 1, body: 'First update'),
      ];
    final controller = SupportTicketController(repository: repository);
    final auth = _authenticatedAuth();

    await tester.pumpWidget(
      MaterialApp(
        home: SupportTicketDetailScreen(
          controller: controller,
          authController: auth,
          ticket: _ticket(unreadCount: 2),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      tester.getTopLeft(find.text('First update')).dy,
      lessThan(tester.getTopLeft(find.text('Second update')).dy),
    );
    await tester.ensureVisible(find.text('Mark as read'));
    await tester.tap(find.text('Mark as read'));
    await tester.pump();

    expect(repository.readSequence, 2);
    expect(find.text('Already read'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });
}

AuthController _authenticatedAuth() {
  return AuthController(
    authRepository: _UnusedAuthRepository(),
    dashboardRepository: _UnusedDashboardRepository(),
  )..status = AuthStatus.authenticated;
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedDashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _WidgetSupportRepository implements SupportTicketRepository {
  bool offlineCreate = false;
  bool showTicket = false;
  int createCount = 0;
  int? readSequence;
  List<SupportTicketEvent> detailEvents = [_event()];

  @override
  Future<SupportTicketPage> list({
    SupportTicketStatusFilter status = SupportTicketStatusFilter.all,
    SupportTicketCategoryFilter category = SupportTicketCategoryFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    return SupportTicketPage(
      items: showTicket ? [_ticket(unreadCount: 2)] : const [],
      nextCursor: null,
    );
  }

  @override
  Future<SupportTicketMutation> create({
    required String subject,
    required String category,
    required String body,
    required String idempotencyKey,
  }) async {
    createCount++;
    if (offlineCreate) {
      throw const ApiException.network('private offline');
    }
    showTicket = true;
    return SupportTicketMutation(
      ticket: _ticket(subject: subject, category: category),
      event: _event(body: body),
    );
  }

  @override
  Future<SupportTicketDetailPage> detail(
    String ticketId, {
    String? cursor,
    int limit = 20,
  }) async {
    return SupportTicketDetailPage(
      ticket: const SupportTicketDetailRecord(
        id: 'ticket-1',
        reference: 'SUP-0001',
        status: 'open',
        revision: 1,
      ),
      events: detailEvents,
      nextCursor: null,
    );
  }

  @override
  Future<SupportTicketSummary> markRead({
    required String ticketId,
    required int lastReadSequence,
  }) async {
    readSequence = lastReadSequence;
    return _ticket(unreadCount: 0);
  }

  @override
  Future<SupportTicketMutation> reply({
    required String ticketId,
    required String body,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    return SupportTicketMutation(
      ticket: _ticket(revision: expectedRevision + 1),
      event: _event(id: 'event-2', sequence: 2, body: body),
    );
  }
}

SupportTicketSummary _ticket({
  String subject = 'Task help',
  String category = 'delivery',
  int revision = 1,
  int unreadCount = 0,
}) {
  return SupportTicketSummary(
    id: 'ticket-1',
    reference: 'SUP-0001',
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
  int sequence = 1,
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
