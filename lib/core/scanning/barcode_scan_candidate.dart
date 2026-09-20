import 'package:mobile_scanner/mobile_scanner.dart';

enum BarcodeScanType { qr, trackingId }

class BarcodeScanCandidate {
  const BarcodeScanCandidate({required this.value, required this.type});

  final String value;
  final BarcodeScanType type;

  String get identifierType => switch (type) {
    BarcodeScanType.qr => 'qr',
    BarcodeScanType.trackingId => 'tracking_id',
  };

  String get typeLabel => switch (type) {
    BarcodeScanType.qr => 'QR payload',
    BarcodeScanType.trackingId => 'tracking ID',
  };

  static BarcodeScanCandidate? fromBarcode(Barcode barcode) {
    final value = barcode.rawValue;
    if (value == null || value.isEmpty) {
      return null;
    }

    final type = switch (barcode.format) {
      BarcodeFormat.qrCode => BarcodeScanType.qr,
      BarcodeFormat.code128 => BarcodeScanType.trackingId,
      _ => null,
    };
    if (type == null) {
      return null;
    }
    return BarcodeScanCandidate(value: value, type: type);
  }
}
