import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

enum DeliveryPhotoCameraFailureKind {
  permissionDenied,
  unavailable,
  busy,
  captureFailed,
}

class DeliveryPhotoCameraFailure implements Exception {
  const DeliveryPhotoCameraFailure(this.kind);

  final DeliveryPhotoCameraFailureKind kind;
}

abstract interface class DeliveryPhotoCameraPlatform {
  Future<DeliveryPhotoCameraSession> openRearCamera();
}

abstract interface class DeliveryPhotoCameraSession {
  double get aspectRatio;

  Widget buildPreview();

  Future<XFile> takePicture();

  Future<void> dispose();
}

class PluginDeliveryPhotoCameraPlatform implements DeliveryPhotoCameraPlatform {
  const PluginDeliveryPhotoCameraPlatform();

  @override
  Future<DeliveryPhotoCameraSession> openRearCamera() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      CameraDescription? rearCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          rearCamera = camera;
          break;
        }
      }
      if (rearCamera == null) {
        throw const DeliveryPhotoCameraFailure(
          DeliveryPhotoCameraFailureKind.unavailable,
        );
      }
      controller = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      return _PluginDeliveryPhotoCameraSession(controller);
    } on DeliveryPhotoCameraFailure {
      await controller?.dispose();
      rethrow;
    } on CameraException catch (error) {
      await controller?.dispose();
      throw DeliveryPhotoCameraFailure(_failureKind(error.code));
    } catch (_) {
      await controller?.dispose();
      throw const DeliveryPhotoCameraFailure(
        DeliveryPhotoCameraFailureKind.unavailable,
      );
    }
  }
}

class _PluginDeliveryPhotoCameraSession implements DeliveryPhotoCameraSession {
  _PluginDeliveryPhotoCameraSession(this.controller);

  final CameraController controller;

  @override
  double get aspectRatio => controller.value.aspectRatio;

  @override
  Widget buildPreview() => CameraPreview(controller);

  @override
  Future<XFile> takePicture() async {
    try {
      return await controller.takePicture();
    } on CameraException catch (error) {
      throw DeliveryPhotoCameraFailure(_failureKind(error.code));
    }
  }

  @override
  Future<void> dispose() => controller.dispose();
}

DeliveryPhotoCameraFailureKind _failureKind(String code) {
  final normalized = code.toLowerCase();
  if (normalized.contains('denied') ||
      normalized.contains('permission') ||
      normalized.contains('restricted') ||
      normalized.contains('access')) {
    return DeliveryPhotoCameraFailureKind.permissionDenied;
  }
  if (normalized.contains('busy') ||
      normalized.contains('active') ||
      normalized.contains('progress')) {
    return DeliveryPhotoCameraFailureKind.busy;
  }
  if (normalized.contains('capture') || normalized.contains('picture')) {
    return DeliveryPhotoCameraFailureKind.captureFailed;
  }
  return DeliveryPhotoCameraFailureKind.unavailable;
}
