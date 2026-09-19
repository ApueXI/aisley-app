part of 'account_screen.dart';

extension _AccountScreenProfilePhoto on _AccountScreenState {
  Future<void> _pickProfilePhoto() async {
    if (_isPickingProfilePhoto ||
        widget.accountController.isBusy ||
        widget.accountController.account?.security.profilePhotoEditable !=
            true) {
      return;
    }

    _updateState(() {
      _isPickingProfilePhoto = true;
      _profilePhotoSelectionError = null;
    });

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_profilePhotoTypeGroup],
      );
      if (file == null) {
        return;
      }

      final fileName = file.name.trim().isEmpty
          ? _fileNameFromPath(file.path)
          : file.name.trim();
      if (!_isAllowedProfilePhotoName(fileName)) {
        _setProfilePhotoSelectionError(
          'Choose a JPEG, JPG, PNG, or WebP image.',
        );
        return;
      }
      if (file.path.trim().isEmpty) {
        _setProfilePhotoSelectionError(
          'The selected photo could not be opened. Choose it again.',
        );
        return;
      }

      final fileSize = await file.length();
      if (fileSize >= _maxProfilePhotoBytes) {
        _setProfilePhotoSelectionError(
          'The photo must be under 10 MB (10,485,760 bytes).',
        );
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length >= _maxProfilePhotoBytes) {
        _setProfilePhotoSelectionError(
          'The photo must be under 10 MB (10,485,760 bytes).',
        );
        return;
      }
      if (!_hasSupportedImageSignature(bytes)) {
        _setProfilePhotoSelectionError(
          'The selected file does not look like a supported image.',
        );
        return;
      }

      if (!mounted) {
        return;
      }
      _updateState(() {
        _pendingProfilePhoto = ProfilePhotoSelection(
          path: file.path,
          fileName: fileName,
          bytes: Uint8List.fromList(bytes),
        );
        _profilePhotoSelectionError = null;
      });
    } catch (_) {
      _setProfilePhotoSelectionError(
        'The photo could not be opened. Choose a supported image and try again.',
      );
    } finally {
      if (mounted) {
        _updateState(() {
          _isPickingProfilePhoto = false;
        });
      }
    }
  }

  void _setProfilePhotoSelectionError(String message) {
    if (!mounted) {
      return;
    }
    _updateState(() {
      _profilePhotoSelectionError = message;
    });
  }

  Future<void> _uploadProfilePhoto() async {
    final selection = _pendingProfilePhoto;
    if (selection == null || widget.accountController.isBusy) {
      return;
    }

    _updateState(() {
      _cancelProfilePhotoUpload = null;
      _profilePhotoSelectionError = null;
    });

    final uploaded = await widget.accountController.uploadProfilePhoto(
      selection,
      onCancel: (cancel) {
        if (mounted) {
          _updateState(() {
            _cancelProfilePhotoUpload = cancel;
          });
        }
      },
    );

    if (!mounted) {
      return;
    }
    _updateState(() {
      _cancelProfilePhotoUpload = null;
      if (uploaded) {
        _pendingProfilePhoto = null;
      }
    });
    await _closeIfSessionEnded();
  }

  void _cancelProfilePhotoUploadRequest() {
    final cancel = _cancelProfilePhotoUpload;
    if (cancel == null) {
      return;
    }
    _updateState(() {
      _cancelProfilePhotoUpload = null;
    });
    cancel();
  }

  Future<void> _discardPendingPhoto() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard selected photo?'),
          content: const Text('The local preview will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (shouldDiscard == true && mounted) {
      _updateState(() {
        _pendingProfilePhoto = null;
        _profilePhotoSelectionError = null;
      });
    }
  }

  Future<void> _removeProfilePhoto() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove profile photo?'),
          content: const Text(
            'This removes the private photo from your Courier account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove photo'),
            ),
          ],
        );
      },
    );
    if (shouldRemove != true || !mounted) {
      return;
    }

    await widget.accountController.deleteProfilePhoto();
    if (mounted) {
      await _closeIfSessionEnded();
    }
  }

  Future<void> _retryProfilePhoto() async {
    await widget.accountController.loadProfilePhoto();
    if (mounted) {
      await _closeIfSessionEnded();
    }
  }
}
