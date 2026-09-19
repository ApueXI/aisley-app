part of '../account_screen.dart';

extension _AccountScreenProfilePhotoView on _AccountScreenState {
  Widget _buildProfilePhotoSection(
    BuildContext context,
    CourierAccount account,
  ) {
    final controller = widget.accountController;
    final scheme = Theme.of(context).colorScheme;
    final pendingPhoto = _pendingProfilePhoto;
    final displayedBytes =
        pendingPhoto?.bytes ?? controller.profilePhoto?.bytes;
    final isPhotoBusy = controller.isProfilePhotoBusy;
    final photoError =
        controller.profilePhotoFieldError('photo') ??
        controller.profilePhotoErrorMessage ??
        _profilePhotoSelectionError;
    final canEdit = account.security.profilePhotoEditable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_camera_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile photo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPEG, JPG, PNG, or WebP under 10 MB.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (displayedBytes != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfilePhotoPreview(bytes: displayedBytes),
                  const SizedBox(width: 14),
                  Expanded(
                    child: pendingPhoto == null
                        ? Text(
                            'Current private profile photo',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local preview — upload to save it to your account.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pendingPhoto.fileName,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                _formatFileSize(pendingPhoto.sizeInBytes),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                  ),
                ],
              )
            else if (controller.profilePhotoStatus ==
                ProfilePhotoStatus.loading)
              Semantics(
                liveRegion: true,
                label: 'Loading your private profile photo',
                child: const LinearProgressIndicator(),
              )
            else
              Text(
                'No profile photo is set.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (controller.profilePhotoStatus ==
                ProfilePhotoStatus.uploading) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: 'Uploading your profile photo',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 8),
              Text('Uploading…', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (controller.profilePhotoStatus ==
                ProfilePhotoStatus.deleting) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: 'Removing your profile photo',
                child: const LinearProgressIndicator(),
              ),
            ],
            if (photoError != null) ...[
              const SizedBox(height: 14),
              _AccountBanner(message: photoError, isError: true),
            ],
            if (controller.profilePhotoSuccessMessage != null) ...[
              const SizedBox(height: 14),
              _AccountBanner(
                message: controller.profilePhotoSuccessMessage!,
                isError: false,
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (pendingPhoto != null)
                    FilledButton.icon(
                      onPressed: isPhotoBusy ? null : _uploadProfilePhoto,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload photo'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: isPhotoBusy || _isPickingProfilePhoto
                          ? null
                          : _pickProfilePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        displayedBytes == null
                            ? 'Choose photo'
                            : 'Replace photo',
                      ),
                    ),
                  if (pendingPhoto != null)
                    TextButton(
                      onPressed: isPhotoBusy ? null : _discardPendingPhoto,
                      child: const Text('Discard'),
                    ),
                  if (pendingPhoto == null && displayedBytes != null)
                    TextButton.icon(
                      onPressed: isPhotoBusy ? null : _removeProfilePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  if (pendingPhoto == null &&
                      controller.profilePhotoStatus ==
                          ProfilePhotoStatus.retryableFailure)
                    TextButton.icon(
                      onPressed: isPhotoBusy ? null : _retryProfilePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry photo'),
                    ),
                  if (controller.profilePhotoStatus ==
                          ProfilePhotoStatus.uploading &&
                      _cancelProfilePhotoUpload != null)
                    TextButton.icon(
                      onPressed: _cancelProfilePhotoUploadRequest,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel upload'),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Profile photo changes are not available for this account.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
