part of '../pickup_screen.dart';

extension _PickupTaskActions on _PickupTaskDetailScreenState {
  Widget _buildRejected(BuildContext context, PickupTask task) {
    final scheme = Theme.of(context).colorScheme;
    final actionStatus = _pickupController.actionStatus(task);
    final error = _pickupController.actionError(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_returned_outlined),
            const SizedBox(height: 10),
            Text(
              'Offer rejected',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              task.rejectionReason == null
                  ? 'Logistics may offer this task again.'
                  : 'Reason: ${task.rejectionReason}',
            ),
            if (task.offerRespondedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Recorded ${_formatManilaTimestamp(task.offerRespondedAt!)}',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (_canRetryAction(actionStatus) &&
                  _pickupController.hasPendingRejection(task))
                TextButton.icon(
                  onPressed: () => _retryRejection(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same rejection'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptance(BuildContext context, PickupTask task) {
    if (task.isFinalMile) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispatch batch offer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Final-mile offers must be accepted as a whole dispatch batch. '
                'Individual task acceptance is unavailable here until the '
                'batch response contract is confirmed.',
              ),
            ],
          ),
        ),
      );
    }
    final controller = _pickupController;
    final actionStatus = controller.actionStatus(task);
    final error = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accept before pickup',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Opening this task does not accept it. Confirm that you are taking responsibility for this assigned ${task.isFirstMile ? 'Seller pickup' : 'hub delivery'} before verifying the parcel.',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (actionStatus == PickupTaskActionStatus.consentRequired &&
                  _policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetryAction(actionStatus) &&
                  controller.hasPendingRejection(task))
                TextButton.icon(
                  onPressed: busy ? null : () => _retryRejection(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same rejection'),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () => _confirmAcceptTask(task),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                task.isFirstMile
                    ? 'Accept Seller pickup'
                    : 'Accept hub delivery',
              ),
            ),
            if (task.isFinalMile) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: busy ? null : () => _confirmRejectTask(task),
                icon: const Icon(Icons.close),
                label: const Text('Reject offer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerification(BuildContext context, PickupTask task) {
    final controller = _pickupController;
    final actionStatus = controller.actionStatus(task);
    final actionError = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final isFinalMile = task.isFinalMile;
    final canSubmit = task.isFirstMile || task.revision != null;
    final scheme = Theme.of(context).colorScheme;
    final pendingFinalSubmission =
        isFinalMile &&
        actionStatus == PickupTaskActionStatus.awaitingValidation &&
        controller.lastFinalMilePickup?.taskId == task.id;
    final verificationLocked = busy || pendingFinalSubmission;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFinalMile ? 'Verify hub handoff' : 'Verify Seller handoff',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isFinalMile
                  ? 'Submit the waybill identifier as evidence. Logistics must validate it before the task becomes picked up from the hub.'
                  : 'Use the waybill QR payload or the printed Order ID/reference. Verification only prepares a candidate; the button below is the physical pickup confirmation.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'qr',
                  label: Text('Waybill QR'),
                  icon: Icon(Icons.qr_code_2),
                ),
                ButtonSegment<String>(
                  value: 'tracking_id',
                  label: Text('Tracking ID'),
                  icon: Icon(Icons.view_week_outlined),
                ),
                ButtonSegment<String>(
                  value: 'order_id',
                  label: Text('Order ID/reference'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: <String>{_identifierType},
              onSelectionChanged: verificationLocked
                  ? null
                  : (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      _pickupSetState(() {
                        _identifierType = selection.first;
                        _resolvedForThisTask = null;
                        _resolutionMessage = null;
                      });
                      controller.clearResolution();
                    },
            ),
            const SizedBox(height: 16),
            if (BarcodeScannerScreen.isSupported) ...[
              OutlinedButton.icon(
                onPressed: verificationLocked ? null : _openScanner,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan QR or tracking ID'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _identifierController,
              enabled: !verificationLocked,
              maxLength: 128,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: switch (_identifierType) {
                  'qr' => 'Waybill QR payload',
                  'tracking_id' => 'Tracking ID',
                  _ => 'Printed Order ID/reference',
                },
                helperText: switch (_identifierType) {
                  'qr' => 'A camera, scanner keyboard, or paste may enter the decoded payload. It is treated as untrusted text.',
                  'tracking_id' => 'Enter the printed Code 128 tracking ID. Review it before confirming pickup.',
                  _ => 'Enter the human-readable reference printed on the waybill.',
                },
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_resolvedForThisTask != null ||
                    _resolutionMessage != null) {
                  _pickupSetState(() {
                    _resolvedForThisTask = null;
                    _resolutionMessage = null;
                  });
                  controller.clearResolution();
                }
              },
            ),
            if (_identifierType == 'qr') ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: verificationLocked || !controller.canRetryRateLimit
                    ? null
                    : _resolveQr,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Check QR match'),
              ),
            ],
            if (_resolutionMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _resolutionMessage!,
                style: TextStyle(
                  color: _resolvedForThisTask == false
                      ? scheme.error
                      : scheme.primary,
                ),
              ),
              if (controller.waybillResolutionStatus ==
                      PickupSectionStatus.consentRequired &&
                  _policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
            ],
            if (actionError != null) ...[
              const SizedBox(height: 12),
              Text(actionError, style: TextStyle(color: scheme.error)),
              if (actionStatus == PickupTaskActionStatus.consentRequired &&
                  _policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetryAction(actionStatus) &&
                  controller.hasPendingAttempt(task))
                TextButton.icon(
                  onPressed:
                      busy ||
                          (actionStatus == PickupTaskActionStatus.rateLimited &&
                              !controller.canRetryRateLimit)
                      ? null
                      : () => _retryPickup(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same attempt'),
                ),
            ],
            if (pendingFinalSubmission) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Awaiting Logistics validation for hub pickup',
                child: Text(
                  'Awaiting Logistics validation. Do not treat this submission as picked up from the hub yet.',
                  style: TextStyle(color: scheme.primary),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy || !canSubmit
                    ? null
                    : () => _submitPickup(task),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isFinalMile
                            ? Icons.upload_outlined
                            : Icons.check_circle_outline,
                      ),
                label: Text(
                  isFinalMile ? 'Submit hub pickup evidence' : 'Confirm pickup',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _canRetryAction(PickupTaskActionStatus status) {
  return status == PickupTaskActionStatus.offline ||
      status == PickupTaskActionStatus.timeout ||
      status == PickupTaskActionStatus.conflict ||
      status == PickupTaskActionStatus.rateLimited ||
      status == PickupTaskActionStatus.failed;
}
