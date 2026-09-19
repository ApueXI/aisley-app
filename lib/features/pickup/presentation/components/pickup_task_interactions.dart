part of '../pickup_screen.dart';

extension _PickupTaskInteractions on _PickupTaskDetailScreenState {
  Future<void> _confirmAcceptTask(PickupTask task) async {
    final shouldAccept = await showDialog<bool>(
      context: _pickupContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Accept this task?'),
          content: Text(
            'Accepting confirms responsibility for this ${task.isFirstMile ? 'Seller pickup' : 'hub delivery'}. It does not record physical pickup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept task'),
            ),
          ],
        );
      },
    );
    if (shouldAccept != true || !_pickupMounted) {
      return;
    }
    await _pickupController.acceptTask(task);
    await _closeIfSessionEnded();
  }

  Future<void> _confirmRejectTask(PickupTask task) async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: _pickupContext,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reject this offer?'),
            content: TextField(
              controller: reasonController,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why can’t you take this task?',
                helperText: 'Enter at least 3 characters.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = reasonController.text.trim();
                  if (value.length < 3 || value.length > 1000) {
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                child: const Text('Reject offer'),
              ),
            ],
          );
        },
      );
      if (reason == null || !_pickupMounted) {
        return;
      }
      await _pickupController.rejectFinalMileTask(task, reason: reason);
      await _closeIfSessionEnded();
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _resolveQr() async {
    final payload = _identifierController.text.trim();
    if (payload.isEmpty) {
      _pickupSetState(() {
        _resolvedForThisTask = false;
        _resolutionMessage = 'Enter or scan a QR payload first.';
      });
      return;
    }
    final resolution = await _pickupController.resolveWaybill(payload);
    if (!_pickupMounted) {
      return;
    }
    if (resolution == null) {
      _pickupSetState(() {
        _resolvedForThisTask = false;
        _resolutionMessage = _pickupController.waybillResolutionError ?? 'The QR could not be matched. You may enter the printed Order reference instead.';
      });
      await _closeIfSessionEnded();
      return;
    }

    final task = _pickupController.taskWithId(widget.task);
    final matches = _resolutionMatchesTask(resolution, task);
    _pickupSetState(() {
      _resolvedForThisTask = matches;
      _resolutionMessage = matches
          ? 'The server matched this QR candidate to this task. Confirm pickup only when you have the parcel.'
          : 'This QR belongs to a different or unavailable task. No pickup was changed.';
    });
  }

  bool _resolutionMatchesTask(WaybillResolution resolution, PickupTask task) {
    if (resolution.taskId != null) {
      return resolution.taskId == task.id;
    }
    final taskOrderReference = task.order?.reference;
    return taskOrderReference != null &&
        taskOrderReference == resolution.orderReference;
  }

  Future<void> _submitPickup(PickupTask task) async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty || identifier.length > 128) {
      _pickupSetState(() {
        _resolvedForThisTask = false;
        _resolutionMessage = 'Enter an identifier up to 128 characters.';
      });
      return;
    }

    if (task.isFirstMile) {
      await _pickupController.confirmFirstMilePickup(
        task,
        identifierType: _identifierType,
        identifier: identifier,
      );
    } else {
      await _pickupController.submitFinalMilePickup(
        task,
        identifierType: _identifierType,
        identifier: identifier,
      );
    }
    await _closeIfSessionEnded();
  }

  Future<void> _retryPickup(PickupTask task) async {
    if (task.isFirstMile) {
      await _pickupController.retryFirstMilePickup(task);
    } else {
      await _pickupController.retryFinalMilePickup(task);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _retryRejection(PickupTask task) async {
    await _pickupController.retryFinalMileRejection(task);
    await _closeIfSessionEnded();
  }

  Future<void> _openPolicies() async {
    final policyController = _policyController;
    if (policyController == null || !_pickupMounted) {
      return;
    }
    await Navigator.of(_pickupContext).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: _authController,
          policyController: policyController,
        ),
      ),
    );
    if (_pickupMounted) {
      await _pickupController.load();
    }
  }

  Future<void> _closeIfSessionEnded() async {
    if (!_pickupMounted || _authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(_pickupContext).canPop()) {
      Navigator.of(_pickupContext).pop();
    }
  }
}
