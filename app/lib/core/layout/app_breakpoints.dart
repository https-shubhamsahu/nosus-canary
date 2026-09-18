import 'package:flutter/material.dart';

/// Layout breakpoints for the Flutter shell.
///
/// Compact is the phone/nav-bar layout. Expanded is a side rail plus a
/// wider content column — not a stretched phone screen.
abstract final class AppBreakpoints {
  static const double expanded = 900;
  static const double contentMaxCompact = 760;
  static const double contentMaxExpanded = 1180;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}
