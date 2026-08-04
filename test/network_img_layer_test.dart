import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';

void main() {
  testWidgets('uses cheaper image effects on constrained devices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkImgLayer(
          src: 'https://example.com/cover.jpg',
          width: 120,
          height: 180,
          reducedEffects: true,
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(image.filterQuality, FilterQuality.low);
  });

  testWidgets('preserves normal effects on unconstrained devices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkImgLayer(
          src: 'https://example.com/cover.jpg',
          width: 120,
          height: 180,
          reducedEffects: false,
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fadeInDuration, const Duration(milliseconds: 120));
    expect(image.fadeOutDuration, const Duration(milliseconds: 120));
    expect(image.filterQuality, FilterQuality.high);
  });
}
