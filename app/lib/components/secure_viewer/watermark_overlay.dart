import 'package:flutter/material.dart';
import 'models/watermark_config.dart';
import 'painters/watermark_painter.dart';

/// A stateless overlay that renders the [WatermarkPainter] over its parent.
///
/// Isolation guarantees:
/// - [RepaintBoundary]: this layer never repaints when the document scrolls
///   or when the blur animation runs.
/// - [IgnorePointer]: events (touch, scroll) pass through transparently.
/// - [SizedBox.expand]: ensures CustomPaint fills the full available space.
///
/// Contrast is document-adaptive (dark outline + light fill on every glyph),
/// not app-theme-adaptive — the app's own light/dark mode has no bearing on
/// what color the PDF/image underneath actually is, so there is nothing to
/// resolve from [Theme.of(context)] here.
class WatermarkOverlay extends StatelessWidget {
  final WatermarkConfig config;

  const WatermarkOverlay({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: WatermarkPainter(config: config),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
