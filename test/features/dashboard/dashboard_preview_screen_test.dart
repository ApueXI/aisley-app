import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/controllers/dashboard_preview_controller.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('partial failure keeps final-mile preview and scaffold honest', (
    tester,
  ) async {
    final repository = _TaskRepository()
      ..firstError = const ApiException.network('private network detail')
      ..finalTasks = [
        _task(
          'final-1',
          PickupTaskLeg.finalMile,
          'delivery_assigned',
          distanceKm: 3.4,
          estimatedDurationMinutes: 12,
        ),
      ];
    final preview = DashboardPreviewController(repository: repository);
    final auth = _auth();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authController: auth,
          dashboardPreviewController: preview,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('First-mile pickup'), findsOneWidget);
    expect(find.text('Final-mile delivery'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Order ORD-final-1'), findsOneWidget);
    expect(find.textContaining('Offered · Assigned'), findsOneWidget);
    expect(find.textContaining('3.4 km'), findsOneWidget);
    expect(find.textContaining('12 min estimate'), findsOneWidget);
    expect(find.textContaining('private network detail'), findsNothing);
    expect(find.text('Accept'), findsNothing);
    await tester.scrollUntilVisible(find.text('Summary unavailable'), 150);
    expect(find.text('Summary unavailable'), findsWidgets);
    expect(find.text('No items available'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    auth.dispose();
  });

  testWidgets('preview tap opens owning list and never accepts a task', (
    tester,
  ) async {
    final repository = _TaskRepository()
      ..firstPage = FirstMileTaskPage(
        tasks: [_task('first-1', PickupTaskLeg.firstMile, 'assigned')],
      );
    final preview = DashboardPreviewController(repository: repository);
    final pickup = PickupController(pickupRepository: repository);
    final auth = _auth();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authController: auth,
          dashboardPreviewController: preview,
          pickupController: pickup,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Order ORD-first-1'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup orders'), findsWidgets);
    expect(repository.firstReads, greaterThanOrEqualTo(2));
    expect(repository.mutations, 0);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.firstReads, greaterThanOrEqualTo(3));
    expect(repository.mutations, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    pickup.dispose();
    auth.dispose();
  });

  testWidgets('unknown task status stays visible but is not a task shortcut', (
    tester,
  ) async {
    final repository = _TaskRepository()
      ..firstPage = FirstMileTaskPage(
        tasks: [_task('unknown', PickupTaskLeg.firstMile, 'future_status')],
      );
    final preview = DashboardPreviewController(repository: repository);
    final auth = _auth();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authController: auth,
          dashboardPreviewController: preview,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Order ORD-unknown'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Order ORD-unknown'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNull);
    expect(find.textContaining('Status unavailable'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    auth.dispose();
  });

  testWidgets('empty first-mile and loading final-mile stay distinct', (
    tester,
  ) async {
    final pending = Completer<List<PickupTask>>();
    final repository = _TaskRepository()..pendingFinal = pending;
    final preview = DashboardPreviewController(repository: repository);
    final auth = _auth();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authController: auth,
          dashboardPreviewController: preview,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No tasks returned by this list.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pending.complete([]);
    await tester.pump();
    expect(find.text('No tasks returned by this list.'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    auth.dispose();
  });

  testWidgets('app resume refetches independent task previews', (
    tester,
  ) async {
    final repository = _TaskRepository();
    final preview = DashboardPreviewController(repository: repository);
    final auth = _auth();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          authController: auth,
          dashboardPreviewController: preview,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final initialReads = repository.firstReads;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(repository.firstReads, greaterThan(initialReads));
    await tester.pumpWidget(const SizedBox.shrink());
    preview.dispose();
    auth.dispose();
  });
}

AuthController _auth() =>
    AuthController(
        authRepository: _UnusedAuthRepository(),
        dashboardRepository: _ScaffoldRepository(),
      )
      ..status = AuthStatus.authenticated
      ..courier = CourierIdentity.fromJson(const {
        'id': 'courier-1',
        'email': 'courier@example.com',
        'role': 'courier',
        'status': 'active',
        'profile': {'first_name': 'Maya', 'last_name': 'Santos'},
        'logistics': {
          'status': 'approved',
          'organization': 'Aisley Express',
          'hub': 'Makati Hub',
        },
      });

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _ScaffoldRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => DashboardSnapshot(
    sections: const {
      'notifications': DashboardSection(
        state: DashboardSectionState.unavailable,
      ),
      'available_tasks': DashboardSection(
        state: DashboardSectionState.unavailable,
      ),
      'active_tasks': DashboardSection(
        state: DashboardSectionState.unavailable,
      ),
    },
    freshness: const DashboardFreshness(
      state: DashboardFreshnessState.scaffold,
    ),
  );
}

PickupTask _task(
  String id,
  PickupTaskLeg leg,
  String status, {
  double? distanceKm,
  int? estimatedDurationMinutes,
}) => PickupTask(
  id: id,
  leg: leg,
  rawStatus: status,
  revision: 1,
  order: PickupOrderReference(reference: 'ORD-$id'),
  distanceKm: distanceKm,
  estimatedDurationMinutes: estimatedDurationMinutes,
);

class _TaskRepository implements PickupRepository {
  FirstMileTaskPage firstPage = const FirstMileTaskPage(tasks: []);
  List<PickupTask> finalTasks = const [];
  Object? firstError;
  Completer<List<PickupTask>>? pendingFinal;
  int firstReads = 0;
  int mutations = 0;

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    firstReads++;
    if (firstError case final error?) throw error;
    return firstPage;
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    if (pendingFinal case final pending?) return pending.future;
    return finalTasks;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw UnimplementedError();
  }
}
