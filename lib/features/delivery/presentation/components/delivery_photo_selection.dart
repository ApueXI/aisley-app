part of '../delivery_screen.dart';

mixin _DeliveryPhotoSelection on State<DeliveryTaskScreen> {
  DeliveryPhotoSelection? _selectedPhoto;
  String? _photoSelectionError;
  bool _isPickingPhoto = false;
  void Function()? _cancelPhotoUpload;

  Future<void> _capturePhoto() async {
    if (_isPickingPhoto) return;
    setState(() {
      _isPickingPhoto = true;
      _photoSelectionError = null;
    });
    try {
      final result = await widget.photoCaptureLauncher.capture(context);
      if (!mounted) return;
      if (result.status == DeliveryPhotoCaptureStatus.chooseFile) {
        setState(() => _isPickingPhoto = false);
        await _pickPhoto();
        return;
      }
      final file = result.file;
      if (result.status == DeliveryPhotoCaptureStatus.captured &&
          file != null) {
        final selection = await loadDeliveryPhotoSelection(
          file,
          captured: true,
        );
        if (!mounted) return;
        setState(() => _selectedPhoto = selection);
        return;
      }
      setState(() => _photoSelectionError = _captureMessage(result.status));
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoSelectionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoSelectionError = 'The captured photo could not be opened. Retake it or choose a photo file.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;
    setState(() {
      _isPickingPhoto = true;
      _photoSelectionError = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_deliveryPhotoTypeGroup],
      );
      if (file == null) {
        setState(
          () => _photoSelectionError = 'Photo selection was cancelled. Choose a photo when you are ready.',
        );
        return;
      }
      final selection = await loadDeliveryPhotoSelection(file, captured: false);
      if (!mounted) return;
      setState(() => _selectedPhoto = selection);
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoSelectionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoSelectionError =
              'The photo could not be opened. Choose it again and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _submitPhoto(PickupTask task) async {
    final photo = _selectedPhoto;
    if (photo == null) return;
    final submitted = await widget.deliveryController.submitProof(
      task,
      photo: photo,
      onCancel: (cancel) {
        if (mounted) setState(() => _cancelPhotoUpload = cancel);
      },
    );
    if (!mounted) return;
    setState(() {
      _cancelPhotoUpload = null;
      if (submitted) _selectedPhoto = null;
    });
  }
}

String _captureMessage(DeliveryPhotoCaptureStatus status) => switch (status) {
  DeliveryPhotoCaptureStatus.cancelled => 'Camera capture was cancelled. Open the camera again or choose a photo file.',
  DeliveryPhotoCaptureStatus.chooseFile =>
    'Choose a JPEG, PNG, or WebP photo under 10 MiB.',
  DeliveryPhotoCaptureStatus.permissionDenied => 'Camera permission was denied. Allow it in Android settings, then retry, or choose a photo file.',
  DeliveryPhotoCaptureStatus.unavailable =>
    'A rear camera is unavailable. Choose a photo file instead.',
  DeliveryPhotoCaptureStatus.busy =>
    'The camera is busy. Wait a moment and retry, or choose a photo file.',
  DeliveryPhotoCaptureStatus.failed =>
    'The photo was not captured. Retake it or choose a photo file.',
  DeliveryPhotoCaptureStatus.captured =>
    'The captured photo could not be opened. Retake it or choose a photo file.',
};
