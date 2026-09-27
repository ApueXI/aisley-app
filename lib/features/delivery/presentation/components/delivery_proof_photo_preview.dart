import 'package:flutter/material.dart';

import '../../domain/delivery_proof_photo.dart';

class DeliveryProofPhotoPreview extends StatelessWidget {
  const DeliveryProofPhotoPreview({
    required this.title,
    required this.status,
    required this.photo,
    required this.errorMessage,
    required this.onRetry,
    this.semanticLabel = 'Private proof of delivery photo',
    super.key,
  });

  final String title;
  final ProofPhotoLoadStatus status;
  final DeliveryProofPhoto? photo;
  final String? errorMessage;
  final VoidCallback onRetry;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final loadedPhoto = status == ProofPhotoLoadStatus.loaded ? photo : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Private image. It is shown only while this authorized screen is open.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (status == ProofPhotoLoadStatus.loading)
          Semantics(
            label: 'Loading private proof photo',
            liveRegion: true,
            child: const LinearProgressIndicator(),
          )
        else if (loadedPhoto != null)
          Semantics(
            label: semanticLabel,
            image: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                loadedPhoto.bytes,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const _PhotoDecodeError(),
              ),
            ),
          )
        else ...[
          Semantics(
            liveRegion: true,
            child: Text(
              errorMessage ?? 'The private proof photo has not loaded.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          if (_canRetry(status)) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry private photo'),
            ),
          ],
        ],
      ],
    );
  }

  bool _canRetry(ProofPhotoLoadStatus status) {
    return status == ProofPhotoLoadStatus.idle ||
        status == ProofPhotoLoadStatus.offline ||
        status == ProofPhotoLoadStatus.timeout ||
        status == ProofPhotoLoadStatus.rateLimited ||
        status == ProofPhotoLoadStatus.failed ||
        status == ProofPhotoLoadStatus.secureStorageFailure;
  }
}

class _PhotoDecodeError extends StatelessWidget {
  const _PhotoDecodeError();

  @override
  Widget build(BuildContext context) {
    return Text(
      'The verified image bytes could not be displayed.',
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
