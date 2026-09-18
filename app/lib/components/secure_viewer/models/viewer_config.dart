import 'package:flutter/material.dart';

/// Immutable configuration for the blur-reveal animation behavior and appearance.
@immutable
class ViewerConfig {
  /// Maximum Gaussian blur sigma when no finger is touching.
  /// 18–24 is visually opaque while remaining GPU-performant.
  final double maxBlurSigma;

  /// Duration of the reveal animation (finger down → content clears).
  /// Keep ≤ 150ms for a snappy, responsive feel.
  final Duration revealDuration;

  /// Duration of the conceal animation (finger up → content blurs).
  /// Slightly longer than reveal gives a satisfying "security seal" feel.
  final Duration concealDuration;

  /// Easing curve for the reveal animation.
  final Curve revealCurve;

  /// Easing curve for the conceal animation.
  final Curve concealCurve;

  /// Optional tint applied over the blur layer (e.g., a very subtle dark wash).
  /// Set to null for a pure Gaussian blur with no color overlay.
  final Color? backdropTint;

  /// The radius of the spyglass viewport (clear touch window).
  final double spyglassRadius;

  const ViewerConfig({
    this.maxBlurSigma = 22.0,
    this.revealDuration = const Duration(milliseconds: 120),
    this.concealDuration = const Duration(milliseconds: 220),
    this.revealCurve = Curves.easeOut,
    this.concealCurve = Curves.easeIn,
    this.backdropTint,
    this.spyglassRadius = 75.0,
  });
}
