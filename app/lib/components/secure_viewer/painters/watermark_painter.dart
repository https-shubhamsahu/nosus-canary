import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/watermark_config.dart';

/// Renders a sparse, diagonally-repeating watermark grid across the full canvas.
///
/// Contrast is DOCUMENT-adaptive, not app-theme-adaptive: each glyph is drawn
/// twice — a translucent dark outline (reads on light document pages) plus a
/// translucent light fill on top (reads on dark document pages) — so the same
/// watermark stays legible regardless of the underlying PDF/image background,
/// independent of whether the app itself is in light or dark mode.
///
/// Performance profile:
/// - Wrapped in RepaintBoundary → repaints ONLY when [shouldRepaint] returns true
/// - All TextPainter objects are created and disposed within a single [paint] call
/// - Canvas rotate + translate = single GPU matrix multiplication (essentially free)
///
/// Security note: This watermark provides LEGAL traceability and VISUAL deterrence.
/// It does NOT cryptographically prevent screen capture by an external camera.
class WatermarkPainter extends CustomPainter {
  final WatermarkConfig config;

  const WatermarkPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    // Only the essentials: who, and when. ("CONFIDENTIAL" / role were dropped
    // — decorative bulk, not traceability-essential — to cut text density.)
    final identity =
        config.name.trim().isEmpty || config.name.trim().toLowerCase() == config.email.trim().toLowerCase()
            ? config.email
            : '${config.name} · ${config.email}';
    final lines = <(String, double, FontWeight)>[
      (identity, config.fontSize + 0.5, FontWeight.w600),
      (config.timestamp, config.fontSize - 1.0, FontWeight.w400),
    ];

    const intraLineGap = 3.5;
    final lineHeight = config.fontSize + intraLineGap;

    // Layout each line once; render as an outline pass + fill pass on top so
    // it contrasts against both light and dark document backgrounds.
    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: config.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final fillColor = Colors.white.withValues(alpha: config.opacity * 1.4);

    final outlinePainters = <TextPainter>[];
    final fillPainters = <TextPainter>[];
    for (final line in lines) {
      final baseStyle = TextStyle(
        fontSize: line.$2,
        fontWeight: line.$3,
        letterSpacing: 0.6,
        height: 1.15,
      );
      outlinePainters.add(TextPainter(
        text: TextSpan(text: line.$1, style: baseStyle.copyWith(foreground: outlinePaint)),
        textDirection: TextDirection.ltr,
      )..layout());
      fillPainters.add(TextPainter(
        text: TextSpan(text: line.$1, style: baseStyle.copyWith(color: fillColor)),
        textDirection: TextDirection.ltr,
      )..layout());
    }

    // Block metrics — sparse: a generous gap between blocks, controlled by
    // tileSpacingY (previously unused; now the primary density knob).
    final blockH = lines.length * lineHeight;
    final rowStep = blockH + config.tileSpacingY;

    // Canvas diagonal determines tile count needed to cover all corners after rotation.
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final cols = (diagonal / config.tileSpacingX).ceil() + 2;
    final rows = (diagonal / rowStep).ceil() + 2;

    final angleRad = config.angleDegrees * math.pi / 180.0;

    canvas.save();
    // Rotate around the canvas center so the grid appears centered.
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.rotate(angleRad);

    for (int row = -rows; row <= rows; row++) {
      for (int col = -cols; col <= cols; col++) {
        canvas.save();
        canvas.translate(col * config.tileSpacingX, row * rowStep);

        double yOffset = 0.0;
        for (var i = 0; i < outlinePainters.length; i++) {
          final outline = outlinePainters[i];
          final fill = fillPainters[i];
          outline.paint(canvas, Offset(-outline.width / 2.0, yOffset));
          fill.paint(canvas, Offset(-fill.width / 2.0, yOffset));
          yOffset += lineHeight;
        }

        canvas.restore();
      }
    }

    canvas.restore();

    for (final tp in outlinePainters) {
      tp.dispose();
    }
    for (final tp in fillPainters) {
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(WatermarkPainter oldDelegate) => oldDelegate.config != config;

  @override
  bool shouldRebuildSemantics(WatermarkPainter oldDelegate) => false;
}
