part of '../pickup_screen.dart';

extension _PickupHubHandoff on _PickupTaskDetailScreenState {
  Widget _buildHubHandoff(BuildContext context, PickupTask task) {
    final controller = _pickupController;
    final status = controller.actionStatus(task);
    final error = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final pending =
        status == PickupTaskActionStatus.awaitingValidation &&
        controller.hubPickupSubmissions.containsKey(task.id);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hub handoff', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Confirm that you are collecting this assigned parcel from the Logistics hub. The task identifies the parcel; no scan or reference entry is needed.',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (status == PickupTaskActionStatus.consentRequired &&
                  _policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetryAction(status) && controller.hasPendingAttempt(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => _retryPickup(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same handoff request'),
                ),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Awaiting Logistics validation. Hub custody has not been recorded yet.',
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : () => _confirmHubHandoff(task),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Submit hub handoff'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmHubHandoff(PickupTask task) async {
    final confirmed = await showDialog<bool>(
      context: _pickupContext,
      builder: (context) => AlertDialog(
        title: const Text('Submit hub handoff?'),
        content: const Text(
          'Logistics must validate this handoff before hub custody is recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit handoff'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_pickupMounted) return;
    await _pickupController.submitFinalMilePickup(task);
    await _closeIfSessionEnded();
  }
}
