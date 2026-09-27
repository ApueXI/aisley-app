import 'package:file_selector/file_selector.dart';

enum DeliveryPhotoCaptureStatus {
  captured,
  cancelled,
  chooseFile,
  permissionDenied,
  unavailable,
  busy,
  failed,
}

class DeliveryPhotoCaptureResult {
  const DeliveryPhotoCaptureResult._({required this.status, this.file});

  const DeliveryPhotoCaptureResult.captured(XFile file)
    : this._(status: DeliveryPhotoCaptureStatus.captured, file: file);

  const DeliveryPhotoCaptureResult.cancelled()
    : this._(status: DeliveryPhotoCaptureStatus.cancelled);

  const DeliveryPhotoCaptureResult.chooseFile()
    : this._(status: DeliveryPhotoCaptureStatus.chooseFile);

  const DeliveryPhotoCaptureResult.permissionDenied()
    : this._(status: DeliveryPhotoCaptureStatus.permissionDenied);

  const DeliveryPhotoCaptureResult.unavailable()
    : this._(status: DeliveryPhotoCaptureStatus.unavailable);

  const DeliveryPhotoCaptureResult.busy()
    : this._(status: DeliveryPhotoCaptureStatus.busy);

  const DeliveryPhotoCaptureResult.failed()
    : this._(status: DeliveryPhotoCaptureStatus.failed);

  final DeliveryPhotoCaptureStatus status;
  final XFile? file;
}
