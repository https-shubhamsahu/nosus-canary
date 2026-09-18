import 'package:flutter/foundation.dart';

/// Immutable configuration for the diagonal repeating watermark overlay.
/// All fields participate in equality — changing any field triggers a repaint.
@immutable
class WatermarkConfig {
  final String name;
  final String role;
  final String email;
  final String timestamp;

  /// Opacity of the watermark text. Subtle but always readable.
  /// Range: 0.0 – 1.0. Default 0.07 (7%).
  final double opacity;

  /// Base font size for secondary lines (email, phone, timestamp).
  final double fontSize;

  /// Horizontal spacing between watermark tile columns (in logical pixels).
  /// Wider = sparser grid, fewer repeats on screen.
  final double tileSpacingX;

  /// Vertical GAP between watermark blocks, on top of the block's own text
  /// height (in logical pixels). Wider = sparser grid.
  final double tileSpacingY;

  /// Rotation angle of the watermark grid in degrees (negative = tilts left).
  final double angleDegrees;

  const WatermarkConfig({
    required this.name,
    required this.role,
    required this.email,
    required this.timestamp,
    this.opacity = 0.12,
    this.fontSize = 12.0,
    this.tileSpacingX = 340.0,
    this.tileSpacingY = 240.0,
    this.angleDegrees = -28.0,
  });

  /// Returns a copy scaled for the risk engine's watermark_intensity
  /// (normal/increased/maximum — see
  /// supabase/migrations/20260710030000_risk_engine.sql and
  /// RiskEngineService). Denser + more opaque watermarking is one of the
  /// engine's few automatic responses that's visible to the viewer rather
  /// than silent — deliberately so, since a would-be leaker seeing heavier
  /// tracing on-screen is itself a deterrent.
  WatermarkConfig scaledForIntensity(String intensity) {
    switch (intensity) {
      case 'maximum':
        return WatermarkConfig(
          name: name,
          role: role,
          email: email,
          timestamp: timestamp,
          opacity: (opacity * 2.2).clamp(0.0, 0.5),
          fontSize: fontSize,
          tileSpacingX: tileSpacingX * 0.45,
          tileSpacingY: tileSpacingY * 0.45,
          angleDegrees: angleDegrees,
        );
      case 'increased':
        return WatermarkConfig(
          name: name,
          role: role,
          email: email,
          timestamp: timestamp,
          opacity: (opacity * 1.5).clamp(0.0, 0.35),
          fontSize: fontSize,
          tileSpacingX: tileSpacingX * 0.7,
          tileSpacingY: tileSpacingY * 0.7,
          angleDegrees: angleDegrees,
        );
      default:
        return this;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatermarkConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          role == other.role &&
          email == other.email &&
          timestamp == other.timestamp &&
          opacity == other.opacity &&
          fontSize == other.fontSize &&
          tileSpacingX == other.tileSpacingX &&
          tileSpacingY == other.tileSpacingY &&
          angleDegrees == other.angleDegrees;

  @override
  int get hashCode => Object.hash(
        name,
        role,
        email,
        timestamp,
        opacity,
        fontSize,
        tileSpacingX,
        tileSpacingY,
        angleDegrees,
      );
}
