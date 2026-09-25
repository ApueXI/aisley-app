import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_task_preview.dart';
import 'package:aisley_app/features/dashboard/presentation/controllers/dashboard_preview_controller.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies each leg without treating an offer as acceptance', () {
    expect(
      dashboardTaskClassification(
        DashboardTaskPreview.fromTask(
          _task('first', PickupTaskLeg.firstMile, 'assigned'),
        ),
        PickupTaskLeg.firstMile,
      ),
      DashboardTaskClass.offered,
    );
    expect(
      dashboardTaskClassification(
        DashboardTaskPreview.fromTask(
          _task('final', PickupTaskLeg.finalMile, 'delivery_assigned'),
        ),
        PickupTaskLeg.finalMile,
      ),
      DashboardTaskClass.offered,
    );
    expect(
      dashboardTaskClassification(
        DashboardTaskPreview.fromTask(
          _task('final', PickupTaskLeg.finalMile, 'out_for_delivery'),
        ),
        PickupTaskLeg.finalMile,
      ),
      DashboardTaskClass.active,
    );
    expect(
      dashboardTaskClassification(
        DashboardTaskPreview.fromTask(
          _task('unknown', PickupTaskLeg.finalMile, 'future_status'),
        ),
        PickupTaskLeg.finalMile,
      ),
      DashboardTaskClass.unclassified,
    );
    expect(
      dashboardTaskClassification(
        DashboardTaskPreview.fromTask(
          _task('wrong-leg', PickupTaskLeg.firstMile, 'accepted'),
        ),
        PickupTaskLeg.finalMile,
      ),
      DashboardTaskClass.unclassified,
    );
    final unknownWireLeg = PickupTask.fromJson(const {
      'id': 'unknown-leg',
      'leg': 'new_leg',
      'status': 'assigned',
    }, defaultLeg: PickupTaskLeg.firstMile);
    expect(unknownWireLeg.leg, PickupTaskLeg.unknown);
    expect(
      dashboardTaskClassification(
        DashboardTaskPreview.fromTask(unknownWireLeg),
        PickupTaskLeg.firstMile,
      ),
      DashboardTaskClass.unclassified,
    );
    expect(
      PickupTask.fromJson(const {
        'id': 'legacy-row',
        'status': 'assigned',
      }, defaultLeg: PickupTaskLeg.firstMile).leg,
      PickupTaskLeg.firstMile,
    );
  });

  test(
    'bounds and deduplicates each source without fabricating totals',
    () async {
      final repository = _PreviewRepository()
        ..firstPage = FirstMileTaskPage(
          tasks: [
            for (var i = 0; i < 5; i++)
              _task('first-$i', PickupTaskLeg.firstMile, 'assigned'),
            _task('first-1', PickupTaskLeg.firstMile, 'accepted', revision: 2),
          ],
          currentPage: 1,
          lastPage: 2,
          total: 12,
        )
        ..finalTasks = [
          for (var i = 0; i < 8; i++)
            _task('final-$i', PickupTaskLeg.finalMile, 'delivery_assigned'),
        ];
      final controller = DashboardPreviewController(repository: repository);

      await controller.refreshAll();

      expect(repository.firstPerPage, [
        DashboardPreviewController.maxPreviewTasks,
      ]);
      expect(controller.firstMile.tasks, hasLength(5));
      expect(controller.firstMile.tasks[1].revision, 2);
      expect(controller.firstMile.firstPageOnly, isTrue);
      expect(controller.finalMile.tasks, hasLength(5));
      expect(controller.finalMile.firstPageOnly, isFalse);
      expect(controller.firstMile.status, DashboardPreviewStatus.loaded);
      expect(controller.finalMile.status, DashboardPreviewStatus.loaded);
      controller.dispose();
    },
  );

  test('one failed source does not erase a successful other source', () async {
    final repository = _PreviewRepository()
      ..firstError = const ApiException.network('private socket detail')
      ..finalTasks = [
        _task('final', PickupTaskLeg.finalMile, 'delivery_accepted'),
      ];
    final controller = DashboardPreviewController(repository: repository);

    await controller.refreshAll();

    expect(controller.firstMile.status, DashboardPreviewStatus.offline);
    expect(controller.firstMile.tasks, isEmpty);
    expect(controller.firstMile.error, isNot(contains('private')));
    expect(controller.finalMile.tasks.single.id, 'final');
    expect(controller.finalMile.status, DashboardPreviewStatus.loaded);
    controller.dispose();
  });

  test('offline refresh keeps bounded old rows visibly stale', () async {
    final repository = _PreviewRepository()
      ..firstPage = FirstMileTaskPage(
        tasks: [_task('first', PickupTaskLeg.firstMile, 'assigned')],
      );
    final controller = DashboardPreviewController(repository: repository);
    await controller.refreshFirstMile();
    repository.firstError = const ApiException.network('offline');

    await controller.refreshFirstMile();

    expect(controller.firstMile.tasks.single.id, 'first');
    expect(controller.firstMile.isStale, isTrue);
    expect(controller.firstMile.status, DashboardPreviewStatus.offline);
    controller.dispose();
  });

  test('an older task revision cannot replace a newer preview row', () async {
    final repository = _PreviewRepository()
      ..firstPage = FirstMileTaskPage(
        tasks: [
          _task('first', PickupTaskLeg.firstMile, 'accepted', revision: 3),
        ],
      );
    final controller = DashboardPreviewController(repository: repository);
    await controller.refreshFirstMile();
    repository.firstPage = FirstMileTaskPage(
      tasks: [_task('first', PickupTaskLeg.firstMile, 'assigned', revision: 2)],
    );

    await controller.refreshFirstMile();

    expect(controller.firstMile.tasks.single.revision, 3);
    expect(controller.firstMile.tasks.single.status, PickupTaskStatus.accepted);
    controller.dispose();
  });

  test('timeout and invalid-filter responses are not empty queues', () async {
    final repository = _PreviewRepository()
      ..firstError = const ApiException.network(
        'private timeout',
        networkFailure: ApiNetworkFailure.timeout,
      )
      ..finalError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'private validation detail',
      );
    final controller = DashboardPreviewController(repository: repository);

    await controller.refreshAll();

    expect(controller.firstMile.status, DashboardPreviewStatus.timeout);
    expect(controller.finalMile.status, DashboardPreviewStatus.failed);
    expect(controller.firstMile.tasks, isEmpty);
    expect(controller.finalMile.tasks, isEmpty);
    controller.dispose();
  });

  test('secure storage failure clears all private preview rows', () async {
    final repository = _PreviewRepository()
      ..finalTasks = [_task('final', PickupTaskLeg.finalMile, 'in_transit')];
    final controller = DashboardPreviewController(repository: repository);
    await controller.refreshFinalMile();
    repository.firstError = TokenStorageException('read', StateError('locked'));

    await controller.refreshFirstMile();

    expect(controller.finalMile.tasks, isEmpty);
    expect(
      controller.firstMile.status,
      DashboardPreviewStatus.secureStorageFailure,
    );
    controller.dispose();
  });

  test('server failure keeps old preview visibly stale', () async {
    final repository = _PreviewRepository()
      ..finalTasks = [_task('final', PickupTaskLeg.finalMile, 'in_transit')];
    final controller = DashboardPreviewController(repository: repository);
    await controller.refreshFinalMile();
    repository.finalError = const ApiException(
      statusCode: 503,
      code: 'SERVER_ERROR',
      message: 'private server detail',
    );

    await controller.refreshFinalMile();

    expect(controller.finalMile.tasks.single.id, 'final');
    expect(controller.finalMile.status, DashboardPreviewStatus.failed);
    expect(controller.finalMile.isStale, isTrue);
    expect(controller.finalMile.error, isNot(contains('private')));
    controller.dispose();
  });

  test('429 delays only the affected source', () async {
    final repository = _PreviewRepository()
      ..firstError = const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'private detail',
        retryAfter: Duration(milliseconds: 40),
      );
    final controller = DashboardPreviewController(repository: repository);
    await controller.refreshFirstMile();
    expect(controller.canRetryFirstMile, isFalse);
    expect(controller.canRetryFinalMile, isTrue);
    await controller.refreshFirstMile();
    expect(repository.firstPerPage, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.canRetryFirstMile, isTrue);
    controller.dispose();
  });

  test('401 clears both sources and hands off to session auth', () async {
    final repository = _PreviewRepository()
      ..finalTasks = [_task('final', PickupTaskLeg.finalMile, 'in_transit')];
    var handedOff = false;
    final controller = DashboardPreviewController(
      repository: repository,
      onAuthFailure: (error) async {
        handedOff = error.statusCode == 401;
      },
    );
    await controller.refreshFinalMile();
    repository.firstError = const ApiException(
      statusCode: 401,
      code: 'UNAUTHENTICATED',
      message: 'private detail',
    );

    await controller.refreshFirstMile();

    expect(handedOff, isTrue);
    expect(controller.firstMile.tasks, isEmpty);
    expect(controller.finalMile.tasks, isEmpty);
    controller.dispose();
  });

  test(
    '403 policy denial clears previews and preserves auth handoff',
    () async {
      final repository = _PreviewRepository()
        ..firstError = const ApiException(
          statusCode: 403,
          code: 'POLICY_CONSENT_REQUIRED',
          message: 'private detail',
        );
      String? code;
      final controller = DashboardPreviewController(
        repository: repository,
        onAuthFailure: (error) async => code = error.code,
      );

      await controller.refreshFirstMile();

      expect(code, 'POLICY_CONSENT_REQUIRED');
      expect(controller.firstMile.status, DashboardPreviewStatus.idle);
      controller.dispose();
    },
  );

  test(
    'newer and cleared requests cannot be overwritten by old results',
    () async {
      final pending = Completer<FirstMileTaskPage>();
      final repository = _PreviewRepository()
        ..pendingFirst = pending
        ..firstPage = FirstMileTaskPage(
          tasks: [_task('new', PickupTaskLeg.firstMile, 'accepted')],
        );
      final controller = DashboardPreviewController(repository: repository);
      final older = controller.refreshFirstMile();
      repository.pendingFirst = null;
      await controller.refreshFirstMile();
      pending.complete(
        FirstMileTaskPage(
          tasks: [_task('old', PickupTaskLeg.firstMile, 'assigned')],
        ),
      );
      await older;
      expect(controller.firstMile.tasks.single.id, 'new');

      final anotherPending = Completer<FirstMileTaskPage>();
      repository.pendingFirst = anotherPending;
      final inFlight = controller.refreshFirstMile();
      controller.clear();
      anotherPending.complete(
        FirstMileTaskPage(
          tasks: [_task('late', PickupTaskLeg.firstMile, 'assigned')],
        ),
      );
      await inFlight;
      expect(controller.firstMile.tasks, isEmpty);
      controller.dispose();
    },
  );
}

PickupTask _task(
  String id,
  PickupTaskLeg leg,
  String status, {
  int revision = 1,
}) => PickupTask(
  id: id,
  leg: leg,
  rawStatus: status,
  revision: revision,
  order: PickupOrderReference(reference: 'ORD-$id'),
);

class _PreviewRepository implements PickupRepository {
  FirstMileTaskPage firstPage = const FirstMileTaskPage(tasks: []);
  List<PickupTask> finalTasks = const [];
  Object? firstError;
  Object? finalError;
  Completer<FirstMileTaskPage>? pendingFirst;
  final List<int> firstPerPage = [];

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    firstPerPage.add(perPage);
    if (firstError case final error?) throw error;
    if (pendingFirst case final pending?) return pending.future;
    return firstPage;
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    if (finalError case final error?) throw error;
    return finalTasks;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
