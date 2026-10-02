import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';

import 'fixtures/schedule_filter_repository.dart';

void main() {
  late ScheduleFilterRepository repository;
  late PickupController controller;
  setUp(() {
    repository = ScheduleFilterRepository();
    controller = PickupController(pickupRepository: repository);
  });
  tearDown(() => controller.dispose());

  test('select and clear forward IDs while preserving final-mile state and task identity', () async {
    await controller.load();
    final hubTasks = controller.finalMileTasks;
    expect(controller.firstMileScheduleOptions, {
      'schedule-a': 'SCH-A',
      'schedule-b': 'SCH-B',
    });
    await controller.selectFirstMileSchedule('schedule-a');
    expect(controller.firstMileTasks.single, same(scheduleTaskA));
    expect(controller.firstMileScheduleId, 'schedule-a');
    await controller.load(); // Pull-to-refresh retains the selected filter.
    await controller.selectFirstMileSchedule(null);
    expect(repository.queries, [null, 'schedule-a', 'schedule-a', null]);
    expect(controller.firstMileScheduleId, isNull);
    expect(controller.firstMileTasks, [scheduleTaskA, scheduleTaskB]);
    expect(repository.finalMileReads, 2); // Only initial and full refresh.
    expect(controller.finalMileTasks, hubTasks);
    expect(controller.finalMileStatus, PickupSectionStatus.loaded);
  });

  test('options deduplicate and never invent schedule IDs from task IDs or references', () async {
    repository.onRead = (_) async => const FirstMileTaskPage(
      tasks: [
        scheduleTaskA,
        scheduleTaskA,
        scheduleTaskB,
        PickupTask(
          id: 'not-a-schedule',
          leg: PickupTaskLeg.firstMile,
          rawStatus: 'assigned',
          schedule: PickupSchedule(reference: 'REF-ONLY'),
        ),
      ],
    );
    await controller.load();
    expect(controller.firstMileScheduleOptions.length, 2);
    await controller.selectFirstMileSchedule('not-a-schedule');
    await controller.selectFirstMileSchedule('REF-ONLY');
    expect(repository.queries, [null]);
    expect(controller.firstMileScheduleId, isNull);
    expect(
      () => controller.firstMileScheduleOptions['injected'] = 'X',
      throwsUnsupportedError,
    );
  });

  test('filtered empty keeps selection and discovered options until explicitly cleared', () async {
    await controller.load();
    repository.onRead = (_) async => const FirstMileTaskPage(tasks: []);
    await controller.selectFirstMileSchedule('schedule-b');
    expect(controller.firstMileStatus, PickupSectionStatus.empty);
    expect(controller.firstMileScheduleId, 'schedule-b');
    expect(controller.firstMileScheduleOptions.length, 2);
    expect(controller.firstMileTasks, isEmpty);
    await controller.selectFirstMileSchedule(null);
    expect(controller.firstMileScheduleOptions, isEmpty);
    expect(controller.firstMilePage?.tasks, isEmpty);
  });

  test('new unfiltered page replaces the bounded option snapshot', () async {
    await controller.load();
    repository.onRead = (_) async =>
        const FirstMileTaskPage(tasks: [scheduleTaskB]);
    await controller.reloadFirstMile();
    expect(controller.firstMileScheduleOptions, {'schedule-b': 'SCH-B'});
    expect(repository.finalMileReads, 1);
  });

  test(
    'wrong-schedule response is a contract failure, not filtered work',
    () async {
      await controller.load();
      repository.onRead = (_) async =>
          const FirstMileTaskPage(tasks: [scheduleTaskB]);
      await controller.selectFirstMileSchedule('schedule-a');
      expect(controller.firstMileStatus, PickupSectionStatus.failed);
      expect(controller.firstMileTasks, isEmpty);
      expect(controller.firstMilePage, isNull);
    },
  );

  final failures = <Object, PickupSectionStatus>{
    const ApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'unavailable',
    ): PickupSectionStatus.failed,
    const ApiException(
      statusCode: 409,
      code: 'TASK_STATE_CONFLICT',
      message: 'changed',
    ): PickupSectionStatus.failed,
    const ApiException(
      statusCode: 422,
      code: 'VALIDATION_ERROR',
      message: 'Invalid schedule.',
    ): PickupSectionStatus.failed,
    const ApiException(
      statusCode: 500,
      code: 'SERVER_ERROR',
      message: 'failed',
    ): PickupSectionStatus.failed,
    const ApiException.network(
      'offline',
      networkFailure: ApiNetworkFailure.offline,
    ): PickupSectionStatus.offline,
    const ApiException.network(
      'timeout',
      networkFailure: ApiNetworkFailure.timeout,
    ): PickupSectionStatus.timeout,
    const ApiContractException('pickup.list'): PickupSectionStatus.failed,
    TokenStorageException('read', StateError('unavailable')):
        PickupSectionStatus.secureStorageFailure,
  };
  for (final failure in failures.entries) {
    test(
      'filter failure ${failure.key.runtimeType} ${failure.value} is not an empty success and retries same filter',
      () async {
        await controller.load();
        repository.onRead = (_) async => throw failure.key;
        await controller.selectFirstMileSchedule('schedule-a');
        expect(controller.firstMileStatus, failure.value);
        expect(controller.firstMileErrorMessage, isNotEmpty);
        expect(controller.firstMileScheduleId, 'schedule-a');
        expect(controller.firstMileTasks, isEmpty);
        expect(controller.finalMileStatus, PickupSectionStatus.loaded);
        repository.onRead = null;
        await controller.reloadFirstMile();
        expect(repository.queries, [null, 'schedule-a', 'schedule-a']);
        expect(repository.finalMileReads, 1);
        expect(controller.firstMileStatus, PickupSectionStatus.loaded);
      },
    );
  }

  test('obsolete success and error cannot overwrite another filter or throttle/sign out', () async {
    await controller.load();
    final oldResponse = Completer<FirstMileTaskPage>();
    repository.onRead = (_) => oldResponse.future;
    final older = controller.selectFirstMileSchedule('schedule-a');
    repository.onRead = null;
    await controller.selectFirstMileSchedule('schedule-b');
    oldResponse.complete(const FirstMileTaskPage(tasks: [scheduleTaskA]));
    await older;
    expect(controller.firstMileTasks.single, same(scheduleTaskB));
    final oldError = Completer<FirstMileTaskPage>();
    repository.onRead = (_) => oldError.future;
    final obsolete = controller.selectFirstMileSchedule('schedule-a');
    repository.onRead = null;
    await controller.selectFirstMileSchedule(null);
    oldError.completeError(
      const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'obsolete denial',
      ),
    );
    await obsolete;
    expect(controller.firstMileStatus, PickupSectionStatus.loaded);
    expect(controller.firstMileErrorMessage, isNull);
    expect(controller.firstMileScheduleOptions.length, 2);
    expect(controller.canRetryRateLimit, isTrue);
  });

  test('switching filter during full refresh preserves the independent final-mile response', () async {
    await controller.load();
    final first = Completer<FirstMileTaskPage>();
    final finalMile = Completer<List<PickupTask>>();
    repository.onRead = (_) => first.future;
    repository.onFinalRead = () => finalMile.future;
    final refresh = controller.load();
    repository.onRead = null;
    await controller.selectFirstMileSchedule('schedule-b');
    expect(controller.firstMileTasks.single, same(scheduleTaskB));
    expect(controller.finalMileStatus, PickupSectionStatus.loading);
    first.complete(const FirstMileTaskPage(tasks: [scheduleTaskA]));
    finalMile.complete(const [scheduleHubTask]);
    await refresh;
    expect(controller.firstMileScheduleId, 'schedule-b');
    expect(controller.firstMileTasks.single, same(scheduleTaskB));
    expect(controller.finalMileTasks.single, same(scheduleHubTask));
    expect(controller.finalMileStatus, PickupSectionStatus.loaded);
  });

  test('an obsolete throttle cannot delay the current filter', () async {
    await controller.load();
    final pending = Completer<FirstMileTaskPage>();
    repository.onRead = (_) => pending.future;
    final obsolete = controller.selectFirstMileSchedule('schedule-a');
    repository.onRead = null;
    await controller.selectFirstMileSchedule('schedule-b');
    pending.completeError(
      const ApiException(
        statusCode: 429,
        code: 'RATE_LIMITED',
        message: 'old response',
        retryAfter: Duration(minutes: 1),
      ),
    );
    await obsolete;
    expect(controller.firstMileStatus, PickupSectionStatus.loaded);
    expect(controller.firstMileScheduleId, 'schedule-b');
    expect(controller.canRetryRateLimit, isTrue);
    expect(controller.retryAfter, isNull);
  });

  test('final-mile authorization denial also invalidates pending first-mile options', () async {
    await controller.load();
    final first = Completer<FirstMileTaskPage>();
    repository.onRead = (_) => first.future;
    repository.onFinalRead = () async => throw const ApiException(
      statusCode: 403,
      code: 'LOGISTICS_ASSOCIATION_INVALID',
      message: 'denied',
    );
    final refresh = controller.load();
    await Future<void>.delayed(Duration.zero);
    first.complete(const FirstMileTaskPage(tasks: [scheduleTaskA]));
    await refresh;
    expect(controller.firstMileStatus, PickupSectionStatus.forbidden);
    expect(controller.firstMileTasks, isEmpty);
    expect(controller.firstMileScheduleOptions, isEmpty);
    expect(controller.firstMileScheduleId, isNull);
  });

  test(
    'clear/logout invalidates pending response and clears private filter state',
    () async {
      await controller.load();
      final pending = Completer<FirstMileTaskPage>();
      repository.onRead = (_) => pending.future;
      final load = controller.selectFirstMileSchedule('schedule-a');
      controller.clear();
      pending.complete(const FirstMileTaskPage(tasks: [scheduleTaskA]));
      await load;
      expect(controller.firstMileScheduleId, isNull);
      expect(controller.firstMileScheduleOptions, isEmpty);
      expect(controller.firstMileTasks, isEmpty);
      expect(controller.finalMileTasks, isEmpty);
      expect(controller.firstMileStatus, PickupSectionStatus.idle);
      repository.onRead = null;
      await controller.load();
      expect(repository.queries.last, isNull);
    },
  );

  for (final code in [401, 403]) {
    test(
      'authorization loss $code clears filter/options and notifies auth boundary',
      () async {
        ApiException? authError;
        controller.dispose();
        controller = PickupController(
          pickupRepository: repository,
          onAuthFailure: (error) async {
            authError = error;
          },
        );
        await controller.load();
        repository.onRead = (_) async => throw ApiException(
          statusCode: code,
          code: 'DENIED',
          message: 'denied',
        );
        await controller.selectFirstMileSchedule('schedule-a');
        expect(controller.firstMileScheduleId, isNull);
        expect(controller.firstMileScheduleOptions, isEmpty);
        expect(controller.firstMileTasks, isEmpty);
        expect(authError?.statusCode, code);
      },
    );
  }

  test(
    'policy consent preserves selection/session and retry honors Retry-After',
    () async {
      await controller.load();
      repository.onRead = (_) async => throw const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: 'Review policy.',
      );
      await controller.selectFirstMileSchedule('schedule-a');
      expect(controller.firstMileStatus, PickupSectionStatus.consentRequired);
      expect(controller.firstMileScheduleId, 'schedule-a');
      repository.onRead = (_) async => throw const ApiException(
        statusCode: 429,
        code: 'RATE_LIMITED',
        message: 'Wait.',
        retryAfter: Duration(seconds: 30),
      );
      await controller.reloadFirstMile();
      await controller.selectFirstMileSchedule(null);
      await controller.reloadFirstMile();
      expect(controller.firstMileScheduleId, isNull);
      expect(controller.firstMileStatus, PickupSectionStatus.rateLimited);
      expect(repository.queries, [null, 'schedule-a', 'schedule-a']);
      expect(repository.finalMileReads, 1);
    },
  );
}
