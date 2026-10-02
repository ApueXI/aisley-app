import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';

import 'fixtures/schedule_filter_repository.dart';

void main() {
  late ScheduleFilterRepository repository;
  late PickupController controller;
  late AuthController auth;
  setUp(() {
    repository = ScheduleFilterRepository();
    controller = PickupController(pickupRepository: repository);
    auth = AuthController(
      authRepository: _AuthStub(),
      dashboardRepository: _DashboardStub(),
    );
  });
  tearDown(() {
    controller.dispose();
    auth.dispose();
  });

  Future<void> show(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: PickupScreen(
            authController: auth,
            pickupController: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(
    WidgetTester tester,
    String reference, {
    bool settle = true,
  }) async {
    final dropdown = find.byType(DropdownButton<String>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    final choice = find
        .descendant(
          of: find.byType(DropdownMenuItem<String>),
          matching: find.text('Schedule $reference'),
        )
        .last;
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets(
    'selects a schedule explicitly and clears back to unfiltered work',
    (tester) async {
      await show(tester);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.textContaining('not all schedules'), findsOneWidget);
      await select(tester, 'SCH-A');
      expect(repository.queries, [null, 'schedule-a']);
      expect(controller.firstMileTasks.single.id, 'first-task-a');
      expect(find.text('ORD-B'), findsNothing);
      expect(find.text('ORD-A'), findsOneWidget);
      expect(find.text('ORD-HUB'), findsOneWidget);
      final clear = find.text('Clear schedule filter');
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(repository.queries, [null, 'schedule-a', null]);
      expect(repository.finalMileReads, 1);
      expect(find.text('ORD-B'), findsOneWidget);
      expect(find.text('Clear schedule filter'), findsNothing);
    },
  );

  testWidgets('filtered empty is honest and retains a visible clear action', (
    tester,
  ) async {
    await show(tester);
    repository.onRead = (_) async => const FirstMileTaskPage(tasks: []);
    await select(tester, 'SCH-B');
    expect(
      find.textContaining(
        'No Seller pickups were returned for the selected schedule.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('No seller pickups are assigned right now.'),
      findsNothing,
    );
    expect(find.text('Clear schedule filter'), findsOneWidget);
    expect(find.text('ORD-HUB'), findsOneWidget);
  });

  testWidgets('loading filter hides old rows while preserving Hub pickups', (
    tester,
  ) async {
    await show(tester);
    final response = Completer<FirstMileTaskPage>();
    repository.onRead = (_) => response.future;
    await select(tester, 'SCH-A', settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ORD-A'), findsNothing);
    expect(find.text('ORD-B'), findsNothing);
    expect(find.text('ORD-HUB'), findsOneWidget);
    response.complete(const FirstMileTaskPage(tasks: [scheduleTaskA]));
    await tester.pumpAndSettle();
    expect(find.text('ORD-A'), findsOneWidget);
  });

  for (final error in [
    const ApiException(
      statusCode: 422,
      code: 'VALIDATION_ERROR',
      message: 'Invalid pickup schedule.',
    ),
    const ApiException.network('offline'),
  ]) {
    testWidgets(
      'failed filtered read shows error and retries without final-mile refresh ${error.statusCode}',
      (tester) async {
        await show(tester);
        repository.onRead = (_) async => throw error;
        await select(tester, 'SCH-A');
        expect(
          find.textContaining('No Seller pickups were returned'),
          findsNothing,
        );
        expect(
          find.textContaining('No seller pickups are assigned'),
          findsNothing,
        );
        expect(find.text('ORD-A'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Clear schedule filter'), findsOneWidget);
        repository.onRead = null;
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(repository.queries, [null, 'schedule-a', 'schedule-a']);
        expect(repository.finalMileReads, 1);
        expect(find.text('ORD-A'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'filter remains labelled, operable and overflow-free at large text size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      try {
        await show(tester, textScale: 2);
        expect(find.text('Pickup schedule'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Pickup schedule')), findsWidgets);
        await select(tester, 'SCH-A');
        await tester.ensureVisible(find.text('Clear schedule filter'));
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Clear schedule filter'), findsOneWidget);
        await tester.tap(find.text('Clear schedule filter'));
        await tester.pumpAndSettle();
        expect(controller.firstMileScheduleId, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _AuthStub implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DashboardStub implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
