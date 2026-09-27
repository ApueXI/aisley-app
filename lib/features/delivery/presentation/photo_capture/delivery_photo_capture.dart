import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'delivery_photo_camera_platform.dart';
import 'delivery_photo_camera_screen.dart';
import 'delivery_photo_capture_result.dart';

abstract interface class DeliveryPhotoCaptureLauncher {
  bool get isSupported;

  Future<DeliveryPhotoCaptureResult> capture(BuildContext context);
}

class CameraDeliveryPhotoCaptureLauncher
    implements DeliveryPhotoCaptureLauncher {
  const CameraDeliveryPhotoCaptureLauncher();

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<DeliveryPhotoCaptureResult> capture(BuildContext context) async {
    if (!isSupported) {
      return const DeliveryPhotoCaptureResult.unavailable();
    }
    final result = await Navigator.of(context).push<DeliveryPhotoCaptureResult>(
      MaterialPageRoute<DeliveryPhotoCaptureResult>(
        builder: (_) => DeliveryPhotoCameraScreen(
          platform: const PluginDeliveryPhotoCameraPlatform(),
        ),
      ),
    );
    return result ?? const DeliveryPhotoCaptureResult.cancelled();
  }
}
