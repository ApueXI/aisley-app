import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/networking/api_client.dart';
import '../../../../core/networking/api_contract_exception.dart';
import '../../../../core/security/token_storage.dart';
import '../../domain/dashboard_task_preview.dart';
import '../../../pickup/data/pickup_repository.dart';
import '../../../pickup/domain/pickup_models.dart';

typedef DashboardPreviewAuthFailure = Future<void> Function(ApiException error);

enum DashboardPreviewStatus {
  idle,
  loading,
  loaded,
  empty,
  offline,
  timeout,
  rateLimited,
  failed,
  secureStorageFailure,
}

class DashboardPreviewSection {
  const DashboardPreviewSection({
    this.status = DashboardPreviewStatus.idle,
    this.tasks = const <DashboardTaskPreview>[],
    this.error,
    this.refreshedAt,
    this.firstPageOnly = false,
  });

  final DashboardPreviewStatus status;
  final List<DashboardTaskPreview> tasks;
  final String? error;
  final DateTime? refreshedAt;
  final bool firstPageOnly;

  bool get isStale =>
      tasks.isNotEmpty &&
      (status == DashboardPreviewStatus.offline ||
          status == DashboardPreviewStatus.timeout ||
          status == DashboardPreviewStatus.rateLimited ||
          status == DashboardPreviewStatus.failed);
}

class DashboardPreviewController extends ChangeNotifier {
  DashboardPreviewController({required this.repository, this.onAuthFailure});

  static const maxPreviewTasks = 5;

  final PickupRepository repository;
  final DashboardPreviewAuthFailure? onAuthFailure;

  DashboardPreviewSection firstMile = const DashboardPreviewSection();
  DashboardPreviewSection finalMile = const DashboardPreviewSection();

  int _sessionEpoch = 0;
  int _firstRequest = 0;
  int _finalRequest = 0;
  Timer? _firstRetryTimer;
  Timer? _finalRetryTimer;
  bool _disposed = false;

  bool get canRetryFirstMile => _firstRetryTimer == null;
  bool get canRetryFinalMile => _finalRetryTimer == null;

  Future<void> refreshAll() async {
    await Future.wait<void>([refreshFirstMile(), refreshFinalMile()]);
  }

  Future<void> refreshFirstMile() => _refresh(PickupTaskLeg.firstMile);

  Future<void> refreshFinalMile() => _refresh(PickupTaskLeg.finalMile);

  Future<void> _refresh(PickupTaskLeg source) async {
    final isFirst = source == PickupTaskLeg.firstMile;
    if (isFirst ? !canRetryFirstMile : !canRetryFinalMile) return;
    final sessionEpoch = _sessionEpoch;
    final requestId = isFirst ? ++_firstRequest : ++_finalRequest;
    final old = isFirst ? firstMile : finalMile;
    _set(
      source,
      DashboardPreviewSection(
        status: DashboardPreviewStatus.loading,
        tasks: old.tasks,
        refreshedAt: old.refreshedAt,
        firstPageOnly: old.firstPageOnly,
      ),
    );

    bool isCurrent() =>
        !_disposed &&
        sessionEpoch == _sessionEpoch &&
        requestId == (isFirst ? _firstRequest : _finalRequest);

    try {
      final List<PickupTask> received;
      final bool firstPageOnly;
      if (isFirst) {
        final page = await repository.fetchFirstMileTasks(
          perPage: maxPreviewTasks,
        );
        received = page.tasks;
        firstPageOnly = page.hasMore;
      } else {
        received = await repository.fetchFinalMileTasks();
        firstPageOnly = false;
      }
      if (!isCurrent()) return;
      final previous = isFirst ? firstMile.tasks : finalMile.tasks;
      final tasks = _boundedTasks(received, previous);
      _set(
        source,
        DashboardPreviewSection(
          status: tasks.isEmpty
              ? DashboardPreviewStatus.empty
              : DashboardPreviewStatus.loaded,
          tasks: tasks,
          refreshedAt: DateTime.now().toUtc(),
          firstPageOnly: firstPageOnly,
        ),
      );
    } on ApiException catch (error) {
      if (!isCurrent()) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        clear();
        await onAuthFailure?.call(error);
        return;
      }
      final status = switch (error.statusCode) {
        429 => DashboardPreviewStatus.rateLimited,
        null when error.networkFailure == ApiNetworkFailure.timeout =>
          DashboardPreviewStatus.timeout,
        null => DashboardPreviewStatus.offline,
        _ => DashboardPreviewStatus.failed,
      };
      if (error.statusCode == 429) {
        _delayRetry(source, error.retryAfter);
      }
      _fail(source, status, switch (status) {
        DashboardPreviewStatus.rateLimited =>
          'Too many requests. Wait before refreshing this task list.',
        DashboardPreviewStatus.timeout =>
          'The task list timed out. Retry when the connection improves.',
        DashboardPreviewStatus.offline =>
          'This task list is offline. Reconnect and retry.',
        _ => 'This task list could not be refreshed. Please retry.',
      });
    } on TokenStorageException {
      if (!isCurrent()) return;
      clear();
      _fail(
        source,
        DashboardPreviewStatus.secureStorageFailure,
        'Secure session storage is unavailable. This task preview cannot be loaded.',
      );
    } on ApiContractException {
      if (!isCurrent()) return;
      _fail(
        source,
        DashboardPreviewStatus.failed,
        'This task list did not match the documented API response.',
      );
    }
  }

  List<DashboardTaskPreview> _boundedTasks(
    List<PickupTask> incoming,
    List<DashboardTaskPreview> previous,
  ) {
    final oldById = {for (final task in previous) task.id: task};
    final byId = <String, DashboardTaskPreview>{};
    for (final sourceTask in incoming) {
      final task = DashboardTaskPreview.fromTask(sourceTask);
      if (byId.length >= maxPreviewTasks && !byId.containsKey(task.id)) {
        continue;
      }
      final existing = byId[task.id] ?? oldById[task.id];
      final oldRevision = existing?.revision;
      final newRevision = task.revision;
      byId[task.id] =
          oldRevision != null &&
              newRevision != null &&
              oldRevision > newRevision
          ? existing!
          : task;
    }
    return List<DashboardTaskPreview>.unmodifiable(byId.values);
  }

  void _fail(
    PickupTaskLeg source,
    DashboardPreviewStatus status,
    String message,
  ) {
    final old = source == PickupTaskLeg.firstMile ? firstMile : finalMile;
    _set(
      source,
      DashboardPreviewSection(
        status: status,
        tasks: old.tasks,
        error: message,
        refreshedAt: old.refreshedAt,
        firstPageOnly: old.firstPageOnly,
      ),
    );
  }

  void _delayRetry(PickupTaskLeg source, Duration? retryAfter) {
    final delay = retryAfter ?? const Duration(seconds: 1);
    final timer = Timer(delay, () {
      if (source == PickupTaskLeg.firstMile) {
        _firstRetryTimer = null;
      } else {
        _finalRetryTimer = null;
      }
      _notify();
    });
    if (source == PickupTaskLeg.firstMile) {
      _firstRetryTimer?.cancel();
      _firstRetryTimer = timer;
    } else {
      _finalRetryTimer?.cancel();
      _finalRetryTimer = timer;
    }
  }

  void _set(PickupTaskLeg source, DashboardPreviewSection section) {
    if (source == PickupTaskLeg.firstMile) {
      firstMile = section;
    } else {
      finalMile = section;
    }
    _notify();
  }

  void clear() {
    _sessionEpoch++;
    _firstRequest++;
    _finalRequest++;
    _firstRetryTimer?.cancel();
    _finalRetryTimer?.cancel();
    _firstRetryTimer = null;
    _finalRetryTimer = null;
    firstMile = const DashboardPreviewSection();
    finalMile = const DashboardPreviewSection();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _firstRetryTimer?.cancel();
    _finalRetryTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
