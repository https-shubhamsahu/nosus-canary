import 'package:flutter/material.dart';

/// Responsive content widths. Phone layouts stay compact; larger screens
/// get a readable column rather than a stretched phone UI.
class AppLayout {
  AppLayout._();

  static const double phone = 560;
  static const double tablet = 840;
  static const double desktop = 1080;

  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1280) return desktop;
    if (width >= 840) return tablet;
    return phone;
  }

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 840;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100;

  static Widget constrain(
    BuildContext context, {
    required Widget child,
    double? maxWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? maxContentWidth(context)),
        child: child,
      ),
    );
  }
}
