part of '../delivery_screen.dart';

class _ProofAndCompletionCard extends StatelessWidget {
  const _ProofAndCompletionCard({
    required this.task,
    required this.controller,
    required this.identifierController,
    required this.identifierType,
    required this.onIdentifierTypeChanged,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final PickupTask task;
  final DeliveryController controller;
  final TextEditingController identifierController;
  final String identifierType;
  final ValueChanged<String> onIdentifierTypeChanged;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final actionStatus = controller.actionStatus(task);
    final actionError = controller.actionError(task);
    final completion = controller.completions[task.id];
    final proof = controller.proofs[task.id];
    final evidenceId = proof?.proofId ?? completion?.evidenceId;
    final evidenceStatus = proof?.evidenceStatus ?? completion?.evidenceStatus;
    final proofRecorded = proof != null || completion?.evidenceId != null;
    final proofRejected = evidenceStatus == 'rejected';
    final busy = controller.isActionBusy(task);
    final proofPending =
        actionStatus == DeliveryActionStatus.proofAwaitingValidation ||
        evidenceStatus == 'awaiting_validation';
    final completionPending = controller.isCompletionPending(task);
    final actionBlocked = !controller.canStartAction(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proof and completion',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'The current P0 proof method is QR or printed Order reference. Photo and signature proof are not enabled.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'qr',
                  label: Text('Delivery QR'),
                  icon: Icon(Icons.qr_code_2),
                ),
                ButtonSegment<String>(
                  value: 'order_id',
                  label: Text('Order reference'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              selected: <String>{identifierType},
              onSelectionChanged: busy || actionBlocked
                  ? null
                  : (values) {
                      if (values.isNotEmpty) {
                        onIdentifierTypeChanged(values.first);
                      }
                    },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: identifierController,
              enabled: !busy && !proofPending && !actionBlocked,
              maxLength: 128,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: identifierType == 'qr'
                    ? 'Raw delivery QR payload'
                    : 'Public Order reference',
                helperText: identifierType == 'qr'
                    ? 'Submit the QR payload exactly as scanned; the server verifies it for this task.'
                    : 'Enter the public Order reference shown above. Database IDs and waybill references are not accepted.',
                border: const OutlineInputBorder(),
              ),
            ),
            if (actionError != null) ...[
              const SizedBox(height: 10),
              Text(
                actionError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (actionStatus == DeliveryActionStatus.consentRequired &&
                  showPolicyAction)
                TextButton.icon(
                  onPressed: onOpenPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus == DeliveryActionStatus.conflict)
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.loadDetails(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh task before retrying'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus != DeliveryActionStatus.conflict &&
                  controller.hasPendingProof(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryProof(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same proof attempt'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus != DeliveryActionStatus.conflict &&
                  controller.hasPendingCompletion(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryCompletion(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same completion attempt'),
                ),
            ],
            if (proofPending || (proofRecorded && !proofRejected)) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: evidenceStatus == 'validated'
                    ? 'Proof validated by Logistics'
                    : 'Proof awaiting Logistics validation',
                child: Text(
                  evidenceStatus == 'validated'
                      ? 'Proof validated by Logistics. This does not mark the delivery complete.'
                      : 'Awaiting Logistics validation. This proof submission does not mean the delivery is complete.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ] else ...[
              if (proofRejected)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Logistics rejected the previous proof. Correct the identifier and submit a new proof attempt.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: busy || actionBlocked
                      ? null
                      : () => controller.submitProof(
                          task,
                          identifierType: identifierType,
                          identifier: identifierController.text,
                        ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Submit proof'),
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Complete delivery',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (controller.completionErrors[task.id] != null) ...[
              Text(
                controller.completionErrors[task.id]!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (completionPending)
              const _AwaitingCompletionText()
            else if (completion?.isDelivered == true)
              const _DeliveredStatusText()
            else if (evidenceId == null)
              const Text(
                'Submit the required proof before sending completion intent.',
              )
            else if (proofRejected)
              const Text(
                'Correct and resubmit the proof after Logistics rejected the previous evidence.',
              )
            else ...[
              Text(
                evidenceStatus == 'awaiting_validation'
                    ? 'Proof is awaiting Logistics validation. Submit completion intent so Logistics can continue validation.'
                    : 'The server returned proof for this task. Submit completion intent to finish the Courier handoff.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy || actionBlocked
                    ? null
                    : () => _confirmCompletion(context, evidenceId),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: const Text('Submit completion'),
              ),
            ],
            OutlinedButton.icon(
              onPressed:
                  busy ||
                      !controller.canRetryRateLimit ||
                      controller.completionStatuses[task.id] ==
                          DeliveryLoadStatus.loading
                  ? null
                  : () => controller.loadCompletion(task),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh completion status'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCompletion(
    BuildContext context,
    String evidenceId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit completion intent?'),
        content: const Text(
          'This sends the server the completion intent for this delivery. It will remain pending until Logistics validates the proof.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit intent'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.submitCompletion(task, evidenceId: evidenceId);
    }
  }
}
