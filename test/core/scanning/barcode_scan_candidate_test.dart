import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:aisley_app/core/scanning/barcode_scan_candidate.dart';
import 'package:aisley_app/core/scanning/barcode_scanner_screen.dart';

void main() {
  test('preserves a QR raw payload as a qr candidate', () {
    final candidate = BarcodeScanCandidate.fromBarcode(
      const Barcode(format: BarcodeFormat.qrCode, rawValue: ' RAW-QR-PAYLOAD '),
    );

    expect(candidate?.identifierType, 'qr');
    expect(candidate?.value, ' RAW-QR-PAYLOAD ');
  });

  test('maps Code 128 to a tracking_id candidate', () {
    final candidate = BarcodeScanCandidate.fromBarcode(
      const Barcode(format: BarcodeFormat.code128, rawValue: 'TRK-100'),
    );

    expect(candidate?.identifierType, 'tracking_id');
    expect(candidate?.value, 'TRK-100');
  });

  test('ignores unsupported or empty barcode values', () {
    expect(
      BarcodeScanCandidate.fromBarcode(
        const Barcode(format: BarcodeFormat.code39, rawValue: 'CODE-39'),
      ),
      isNull,
    );
    expect(
      BarcodeScanCandidate.fromBarcode(
        const Barcode(format: BarcodeFormat.qrCode),
      ),
      isNull,
    );
  });

  testWidgets('shows manual fallback without starting a Linux camera', (
    tester,
  ) async {
    if (BarcodeScannerScreen.isSupported) {
      return;
    }

    await tester.pumpWidget(const MaterialApp(home: BarcodeScannerScreen()));

    expect(
      find.text('Camera scanning is not available on this platform.'),
      findsOneWidget,
    );
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('Use manual input'), findsNothing);
  });
}
