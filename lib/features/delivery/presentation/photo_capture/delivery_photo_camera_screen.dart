import 'dart:async';

import 'package:flutter/material.dart';

import 'delivery_photo_camera_platform.dart';
import 'delivery_photo_capture_result.dart';

class DeliveryPhotoCameraScreen extends StatefulWidget {
  const DeliveryPhotoCameraScreen({required this.platform, super.key});

  final DeliveryPhotoCameraPlatform platform;

  @override
  State<DeliveryPhotoCameraScreen> createState() =>
      _DeliveryPhotoCameraScreenState();
}

class _DeliveryPhotoCameraScreenState extends State<DeliveryPhotoCameraScreen>
    with WidgetsBindingObserver {
  DeliveryPhotoCameraSession? _session;
  DeliveryPhotoCameraFailureKind? _failure;
  bool _initializing = true;
  bool _capturing = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed && _session == null) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    final request = ++_request;
    final priorSession = _session;
    _session = null;
    await priorSession?.dispose();
    if (!mounted || request != _request) return;
    setState(() {
      _initializing = true;
      _capturing = false;
      _failure = null;
    });
    try {
      final session = await widget.platform.openRearCamera();
      if (!mounted || request != _request) {
        await session.dispose();
        return;
      }
      setState(() {
        _session = session;
        _initializing = false;
      });
    } on DeliveryPhotoCameraFailure catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _initializing = false;
        _failure = error.kind;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _initializing = false;
        _failure = DeliveryPhotoCameraFailureKind.unavailable;
      });
    }
  }

  void _releaseCamera() {
    _request++;
    final session = _session;
    _session = null;
    unawaited(session?.dispose());
    if (mounted) {
      setState(() {
        _initializing = true;
        _capturing = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final session = _session;
    if (session == null || _capturing) return;
    setState(() {
      _capturing = true;
      _failure = null;
    });
    try {
      final file = await session.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(DeliveryPhotoCaptureResult.captured(file));
    } on DeliveryPhotoCameraFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _failure = error.kind;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _failure = DeliveryPhotoCameraFailureKind.captureFailed;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request++;
    unawaited(_session?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo proof camera')),
      body: SafeArea(
        child: _initializing
            ? const _CameraLoading()
            : _session == null
            ? _CameraUnavailable(
                failure: _failure ?? DeliveryPhotoCameraFailureKind.unavailable,
                onRetry: _initialize,
                onChooseFile: () =>
                    Navigator.of(context)
                        .pop(const DeliveryPhotoCaptureResult.chooseFile()),
              )
            : Column(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _session!.aspectRatio,
                          child: Semantics(
                            label: 'Rear camera preview for photo proof',
                            child: _session!.buildPreview(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Photograph the delivered parcel or approved drop-off area. Avoid unrelated people, rooms, and documents.',
                        ),
                        if (_failure != null) ...[
                          const SizedBox(height: 12),
                          _CameraFailureNotice(failure: _failure!),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _capturing ? null : _takePhoto,
                          icon: _capturing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _capturing ? 'Capturing photo…' : 'Take POD photo',
                          ),
                        ),
                        TextButton(
                          onPressed: _capturing
                              ? null
                              : () => Navigator.of(context).pop(
                                  const DeliveryPhotoCaptureResult.cancelled(),
                                ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Opening rear camera',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.failure,
    required this.onRetry,
    required this.onChooseFile,
  });

  final DeliveryPhotoCameraFailureKind failure;
  final VoidCallback onRetry;
  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            const SizedBox(height: 16),
            _CameraFailureNotice(failure: failure),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry camera'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onChooseFile,
              child: const Text('Use file chooser instead'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraFailureNotice extends StatelessWidget {
  const _CameraFailureNotice({required this.failure});

  final DeliveryPhotoCameraFailureKind failure;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure) {
      DeliveryPhotoCameraFailureKind.permissionDenied => 'Camera permission was denied. Allow camera access in Android settings, then retry, or choose a photo file.',
      DeliveryPhotoCameraFailureKind.busy =>
        'The camera is busy. Wait a moment and retry, or choose a photo file.',
      DeliveryPhotoCameraFailureKind.captureFailed =>
        'The photo was not captured. Keep the app open and retry.',
      DeliveryPhotoCameraFailureKind.unavailable =>
        'A rear camera is unavailable. Choose an existing photo file instead.',
    };
    return Semantics(
      liveRegion: true,
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
