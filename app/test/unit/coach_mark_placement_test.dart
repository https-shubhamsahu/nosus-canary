import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/components/coach_mark.dart';

void main() {
  test('web placement keeps a chrome floor even when padding is zero', () {
    const media = MediaQueryData(size: Size(390, 700));
    final webInset = CoachMarkPlacement.bottomInset(media, isWeb: true);
    final nativeInset = CoachMarkPlacement.bottomInset(media, isWeb: false);

    expect(webInset, CoachMarkPlacement.webBottomChrome);
    expect(nativeInset, 0);

    final safe = CoachMarkPlacement.safeViewport(
      const Size(390, 700),
      media,
      isWeb: true,
    );
    expect(safe.bottom, lessThan(700 - CoachMarkPlacement.webBottomChrome));
    expect(safe.height, greaterThan(400));
  });

  test('treats a target below the fold as not visible', () {
    const viewport = Rect.fromLTWH(24, 12, 342, 640);
    const offscreen = Rect.fromLTWH(40, 900, 300, 80);
    const onscreen = Rect.fromLTWH(40, 200, 300, 80);

    expect(CoachMarkPlacement.targetVisible(offscreen, viewport), isFalse);
    expect(CoachMarkPlacement.targetVisible(onscreen, viewport), isTrue);
    expect(CoachMarkPlacement.targetVisible(null, viewport), isFalse);
  });

  test('places the tip above a target that sits on the bottom edge', () {
    const viewport = Rect.fromLTWH(24, 12, 342, 640);
    const lowTarget = Rect.fromLTWH(40, 520, 300, 120);

    expect(CoachMarkPlacement.placeBelow(lowTarget, viewport), isFalse);
  });
}
