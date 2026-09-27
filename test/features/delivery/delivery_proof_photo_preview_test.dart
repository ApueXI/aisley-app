import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/delivery/domain/delivery_proof_photo.dart';
import 'package:aisley_app/features/delivery/presentation/components/delivery_proof_photo_preview.dart';

void main() {
  testWidgets('private photo preview exposes an accessible image label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryProofPhotoPreview(
            title: 'Submitted photo',
            status: ProofPhotoLoadStatus.loaded,
            photo: DeliveryProofPhoto(
              bytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]),
              contentType: 'image/jpeg',
            ),
            errorMessage: null,
            onRetry: () {},
            semanticLabel: 'Submitted proof of delivery photo',
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Submitted proof of delivery photo'),
      findsOneWidget,
    );
    expect(find.textContaining('Private image.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('offline private photo state offers an explicit retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryProofPhotoPreview(
            title: 'Proof of delivery photo',
            status: ProofPhotoLoadStatus.offline,
            photo: null,
            errorMessage: 'The private photo could not be loaded offline.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.textContaining('loaded offline'), findsOneWidget);
    await tester.tap(find.text('Retry private photo'));
    expect(retried, isTrue);
  });
}
