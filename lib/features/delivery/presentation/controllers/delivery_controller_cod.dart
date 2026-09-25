part of 'delivery_controller.dart';

extension DeliveryControllerCod on DeliveryController {
  Future<DeliveryCodCollection?> prepareCodCompletion(PickupTask task) {
    final proofId =
        proofs[task.id]?.proofId ?? completions[task.id]?.evidenceId;
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        proofId == null ||
        evidenceStatusFor(task) == 'rejected' ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return Future<DeliveryCodCollection?>.value(null);
    }
    return _readCodCollection(task);
  }

  Future<DeliveryCodCollection?> _readCodCollection(PickupTask task) async {
    final epoch = _loadEpoch;
    _actionStatuses[task.id] = DeliveryActionStatus.completionLoading;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();

    try {
      final context = await deliveryRepository.fetchDeliveryContext(task.id);
      if (epoch != _loadEpoch) return null;
      if (context.taskId != task.id) {
        throw const ApiContractException('delivery.context.task_id');
      }
      if (context.status != 'out_for_delivery' || context.revision == null) {
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery task changed. Refresh it before confirming cash collection.';
        _notifyDeliveryListeners();
        return null;
      }

      contexts[task.id] = context;
      contextStatuses[task.id] = DeliveryLoadStatus.loaded;
      contextErrors[task.id] = null;
      _replaceTask(
        (taskById(task.id) ?? task).copyWith(revision: context.revision),
      );

      if (context.paymentMethod != 'cod') {
        _setLocalValidationError(
          task,
          'This delivery has no supported COD payment method. Refresh the task; completion is unavailable.',
        );
        return null;
      }
      final collection = context.codCollection;
      if (collection == null) {
        _setLocalValidationError(
          task,
          'The Order payable total, currency, or pending payment status is unavailable. Refresh delivery details before confirming cash collection.',
        );
        return null;
      }
      _actionStatuses[task.id] = DeliveryActionStatus.idle;
      _notifyDeliveryListeners();
      return collection;
    } on ApiException catch (error) {
      if (epoch == _loadEpoch) await _setActionError(task, error);
    } on TokenStorageException {
      if (epoch == _loadEpoch) _setStorageActionError(task);
    } on ApiContractException catch (error) {
      if (epoch == _loadEpoch) _setContractActionError(task, error);
    }
    return null;
  }
}
