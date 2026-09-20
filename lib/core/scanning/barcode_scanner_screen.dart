import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'barcode_scan_candidate.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({this.title = 'Scan parcel code', super.key});

  final String title;

  static bool get isSupported {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: <BarcodeFormat>[BarcodeFormat.qrCode, BarcodeFormat.code128],
  );

  bool _didCapture = false;
  bool _showDecodeError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(
        WebBarcodeReader.zxingWasm,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!BarcodeScannerScreen.isSupported || _didCapture) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_controller.value.isRunning &&
            !_controller.value.isStarting &&
            _controller.value.hasCameraPermission) {
          unawaited(_controller.start());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!BarcodeScannerScreen.isSupported) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _UnsupportedScannerMessage(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Semantics(
                label: 'Live camera preview for QR and Code 128 tracking ID',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      onDetectError: _onDetectError,
                      errorBuilder: _buildScannerError,
                      placeholderBuilder: (context) => const ColoredBox(
                        color: Colors.black,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 280,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    if (_showDecodeError)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          color: Colors.black87,
                          child: const Text(
                            'The camera could not read that frame. Try again or use manual input.',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  const Text(
                    'Scan a parcel QR code or Code 128 tracking ID. Scanning only fills the form; review it before submitting.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_alt_outlined),
                    label: const Text('Use manual input'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didCapture) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final candidate = BarcodeScanCandidate.fromBarcode(barcode);
      if (candidate == null) {
        continue;
      }
      _didCapture = true;
      unawaited(_returnCandidate(candidate));
      return;
    }
  }

  Future<void> _returnCandidate(BarcodeScanCandidate candidate) async {
    try {
      await _controller.stop();
    } finally {
      if (mounted) {
        Navigator.of(context).pop(candidate);
      }
    }
  }

  void _onDetectError(Object error, StackTrace stackTrace) {
    if (!mounted || _showDecodeError) {
      return;
    }
    setState(() {
      _showDecodeError = true;
    });
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => 'Camera permission was denied. Allow camera access or use manual input.',
      MobileScannerErrorCode.unsupported =>
        'Camera scanning is unavailable on this device. Use manual input.',
      _ => 'The camera could not start. Try again or use manual input.',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _UnsupportedScannerMessage extends StatelessWidget {
  const _UnsupportedScannerMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.no_photography_outlined, size: 48),
        const SizedBox(height: 16),
        Text(
          'Camera scanning is not available on this platform.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use manual input. Camera scanning is enabled only for the Android release app and the Flutter web-server build.',
        ),
      ],
    );
  }
}
