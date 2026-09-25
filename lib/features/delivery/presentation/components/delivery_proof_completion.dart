part of '../delivery_screen.dart';

class _ProofAndCompletionCard extends StatelessWidget {
  const _ProofAndCompletionCard({
    required this.task,
    required this.controller,
    required this.selectedPhoto,
    required this.selectionError,
    required this.isPicking,
    required this.canCancelUpload,
    required this.onChoosePhoto,
    required this.onDiscardPhoto,
    required this.onSubmitPhoto,
    required this.onCancelUpload,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final PickupTask task;
  final DeliveryController controller;
  final DeliveryPhotoSelection? selectedPhoto;
  final String? selectionError;
  final bool isPicking;
  final bool canCancelUpload;
  final VoidCallback onChoosePhoto;
  final VoidCallback onDiscardPhoto;
  final VoidCallback onSubmitPhoto;
  final VoidCallback onCancelUpload;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final actionStatus = controller.actionStatus(task);
    final actionError = controller.actionError(task);
    final completion = controller.completions[task.id];
    final proof = controller.proofs[task.id];
    final evidenceStatus = controller.evidenceStatusFor(task);
    final failedNewProof = actionError != null && proof == null;
    final evidenceId = failedNewProof
        ? null
        : proof?.proofId ?? completion?.evidenceId;
    final proofRejected = evidenceStatus == 'rejected';
    final completionPending =
        !failedNewProof && controller.isCompletionPending(task);
    final busy = controller.isActionBusy(task);
    final actionBlocked = !controller.canStartAction(task);
    final canChoosePhoto =
        !busy &&
        !actionBlocked &&
        !isPicking &&
        !controller.hasPendingProof(task) &&
        !completionPending &&
        (evidenceId == null || proofRejected);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photo proof of delivery',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a JPEG, PNG, or WebP photo under 10 MiB. '
              'The server checks this photo for the current delivery task.',
            ),
            if (proofRejected) ...[
              const SizedBox(height: 12),
              Text(
                'Logistics rejected the previous photo. Choose a new photo and submit a new proof.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (canChoosePhoto) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onChoosePhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  selectedPhoto == null ? 'Choose photo' : 'Change photo',
                ),
              ),
            ],
            if (isPicking)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (selectionError != null) ...[
              const SizedBox(height: 8),
              Text(
                selectionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (selectedPhoto != null && canChoosePhoto) ...[
              const SizedBox(height: 12),
              Semantics(
                label: 'Selected proof photo preview',
                child: Image.memory(
                  selectedPhoto!.bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Photo preview unavailable.'),
                ),
              ),
              TextButton(
                onPressed: onDiscardPhoto,
                child: const Text('Remove photo'),
              ),
              FilledButton.icon(
                onPressed: onSubmitPhoto,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Submit photo proof'),
              ),
            ],
            if (actionStatus == DeliveryActionStatus.proofSubmitting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              if (canCancelUpload)
                TextButton(
                  onPressed: onCancelUpload,
                  child: const Text('Cancel upload'),
                ),
            ],
            if (actionError != null) ...[
              const SizedBox(height: 12),
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
              if (actionStatus == DeliveryActionStatus.conflict)
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
                  label: const Text('Retry same photo upload'),
                ),
              if (_canRetry(actionStatus) &&
                  actionStatus != DeliveryActionStatus.conflict &&
                  controller.hasPendingCompletion(task))
                TextButton.icon(
                  onPressed: busy || !controller.canRetryRateLimit
                      ? null
                      : () => controller.retryCompletion(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same Delivered intent'),
                ),
            ],
            if (evidenceId != null && !proofRejected) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  evidenceStatus == 'validated'
                      ? 'Photo proof validated by Logistics. Delivery is not complete until Logistics validates the completion intent.'
                      : 'Photo proof received. Awaiting Logistics validation; this does not mark the Order delivered.',
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Delivered intent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (controller.completionErrors[task.id] != null) ...[
              Text(
                controller.completionErrors[task.id]!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (completion?.isDelivered == true)
              const _DeliveredStatusText()
            else if (completionPending)
              const _AwaitingCompletionText()
            else if (evidenceId == null)
              const Text('Submit photo proof before sending Delivered intent.')
            else if (proofRejected)
              const Text('Submit a new photo proof after Logistics rejection.')
            else ...[
              const Text(
                'Send a separate Delivered intent for this photo. '
                'Logistics will decide when the delivery is complete.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    busy ||
                        actionBlocked ||
                        controller.hasPendingCompletion(task)
                    ? null
                    : () => _confirmCompletion(context, evidenceId),
                icon: const Icon(Icons.done_all),
                label: const Text('Submit Delivered intent'),
              ),
            ],
            const SizedBox(height: 8),
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
    final collection = await controller.prepareCodCompletion(task);
    if (!context.mounted || collection == null) return;
    var cashConfirmed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirm COD collection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount to collect: ${collection.displayAmount}'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: cashConfirmed,
                  onChanged: (value) =>
                      setDialogState(() => cashConfirmed = value == true),
                  title: Text(
                    'I collected ${collection.displayAmount} in full.',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submitting this photo-linked intent does not complete delivery. Logistics must validate the proof and collection.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: cashConfirmed
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Submit intent'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.submitCompletion(
        task,
        evidenceId: evidenceId,
        confirmedCollection: collection,
      );
    }
  }
}
