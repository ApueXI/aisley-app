part of 'delivery_controller.dart';

extension DeliveryControllerReconciliation on DeliveryController {
  void _replaceTask(PickupTask updated) {
    tasks = List<PickupTask>.unmodifiable(
      tasks.map((task) => task.id == updated.id ? updated : task),
    );
  }

  void _syncTaskFromCompletion(
    PickupTask task,
    CompletionProjection completion, {
    bool allowDelivered = true,
  }) {
    final status = completion.isDelivered && !allowDelivered
        ? task.rawStatus
        : completion.taskStatus;
    _replaceTask(
      task.copyWith(rawStatus: status, revision: completion.revision),
    );
    if (completion.isDelivered && allowDelivered) {
      _actionStatuses[task.id] = DeliveryActionStatus.completed;
    }
  }

  void _reconcileActionWithCompletion(
    String taskId,
    CompletionProjection completion,
  ) {
    if (completion.isDelivered) {
      return;
    }
    if (completion.isAwaitingValidation &&
        _completionMatchesCurrentProof(taskId, completion)) {
      _actionStatuses[taskId] =
          DeliveryActionStatus.completionAwaitingValidation;
      _actionErrors.remove(taskId);
      _actionRetryAfter.remove(taskId);
      return;
    }
    final actionStatus = _actionStatuses[taskId];
    if (actionStatus == DeliveryActionStatus.conflict ||
        actionStatus == DeliveryActionStatus.proofAwaitingValidation ||
        actionStatus == DeliveryActionStatus.completionAwaitingValidation) {
      _actionStatuses.remove(taskId);
      _actionErrors.remove(taskId);
      _actionRetryAfter.remove(taskId);
    }
  }

  bool _completionMatchesCurrentProof(
    String taskId,
    CompletionProjection completion,
  ) {
    final proofId = proofs[taskId]?.proofId;
    final evidenceId = completion.evidenceId;
    return proofId == null || evidenceId == null || proofId == evidenceId;
  }

  int? _latestRevision(PickupTask task) {
    final taskRevision = task.revision;
    final projectionRevision = completions[task.id]?.revision;
    if (taskRevision == null) {
      return projectionRevision;
    }
    if (projectionRevision == null) {
      return taskRevision;
    }
    return projectionRevision > taskRevision
        ? projectionRevision
        : taskRevision;
  }
}
