part of 'pickup_controller.dart';

extension _PickupControllerState on PickupController {
  void _replaceTask(PickupTask updated) {
    if (updated.isFirstMile) {
      firstMileTasks = List<PickupTask>.unmodifiable(
        firstMileTasks
            .map(
              (task) =>
                  PickupController._taskKey(task) ==
                      PickupController._taskKey(updated)
                  ? updated
                  : task,
            )
            .toList(growable: false),
      );
    } else {
      finalMileTasks = List<PickupTask>.unmodifiable(
        finalMileTasks
            .map(
              (task) =>
                  PickupController._taskKey(task) ==
                      PickupController._taskKey(updated)
                  ? updated
                  : task,
            )
            .toList(growable: false),
      );
    }
  }

  _PendingPickupAttempt _pendingAttempt(
    PickupTask task, {
    required String identifierType,
    required String identifier,
  }) {
    final key = PickupController._taskKey(task);
    final existing = _pendingAttempts[key];
    if (existing != null &&
        existing.identifierType == identifierType &&
        existing.identifier == identifier) {
      return existing;
    }

    final pending = _PendingPickupAttempt(
      leg: task.leg,
      identifierType: identifierType,
      identifier: identifier,
      idempotencyKey: PickupController._newUuid(),
    );
    _pendingAttempts[key] = pending;
    return pending;
  }
}
