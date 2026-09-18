import 'package:flutter/material.dart';
import 'models/watermark_config.dart';
import 'models/viewer_config.dart';
import 'blur_reveal_layer.dart';
import 'watermark_overlay.dart';

/// Public API widget for the NO SUS secure document viewer system.
///
/// Composes [BlurRevealLayer] and [WatermarkOverlay] into a single, clean
/// surface. Callers provide [child] (any scrollable document widget) plus
/// the watermark and viewer configurations.
///
/// ## Usage
///
/// ```dart
/// SecureDocumentViewer(
///   watermarkConfig: WatermarkConfig(
///     email: 'user@example.com',
///     phone: '+91 98765 43210',
///     timestamp: '2026-06-09 13:06 IST',
///   ),
///   child: SingleChildScrollView(
///     child: MarkdownBody(data: markdownContent),
///   ),
/// )
/// ```
///
/// ## Security notes
///
/// - Content is blurred by default; cleared only while finger touches screen.
/// - Watermark persists at all blur states — always present on external camera footage.
/// - Screenshot blocking requires platform-level integration (FLAG_SECURE on Android).
/// - External cameras CANNOT be blocked; this system provides friction + traceability.
class SecureDocumentViewer extends StatelessWidget {
  /// The document content to protect. Typically a [SingleChildScrollView]
  /// containing text, a PDF widget, or a [ListView] of pages.
  final Widget child;

  /// Watermark configuration: user identity + timestamp.
  final WatermarkConfig watermarkConfig;

  /// Blur behavior and animation configuration.
  final ViewerConfig viewerConfig;

  /// Whether to show the "TOUCH TO REVEAL" interaction hint.
  final bool showHint;

  /// Whether the touch-to-reveal blur layer is enabled.
  final bool touchToRevealEnabled;

  /// Whether the watermark overlay layer is enabled.
  final bool watermarkEnabled;

  /// Forces an immediate conceal (blur) regardless of [touchToRevealEnabled]
  /// — wired to [WebSecurityGuard]'s detections on the web viewers (DevTools
  /// opened, repeated tab-hiding). When this is provided, the blur layer is
  /// always present so it has something to conceal, even if the sender
  /// didn't request touch-to-reveal-by-default; it just starts revealed in
  /// that case (see [BlurRevealLayer.initiallyConcealed]) rather than
  /// blurred until the first tap.
  final Stream<void>? forceConcealSignal;

  const SecureDocumentViewer({
    super.key,
    required this.child,
    required this.watermarkConfig,
    this.viewerConfig = const ViewerConfig(),
    this.showHint = true,
    this.touchToRevealEnabled = true,
    this.watermarkEnabled = true,
    this.forceConcealSignal,
  });

  @override
  Widget build(BuildContext context) {
    if (touchToRevealEnabled || forceConcealSignal != null) {
      return BlurRevealLayer(
        config: viewerConfig,
        showHint: showHint && touchToRevealEnabled,
        initiallyConcealed: touchToRevealEnabled,
        forceConcealSignal: forceConcealSignal,
        overlay: watermarkEnabled
            ? WatermarkOverlay(config: watermarkConfig)
            : const SizedBox.shrink(),
        child: child,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Protected document content ──────────────────────────
        RepaintBoundary(child: child),
        // ── Layer 2: Always-visible overlay (watermark) ──────────────────
        if (watermarkEnabled) WatermarkOverlay(config: watermarkConfig),
      ],
    );
  }
}

