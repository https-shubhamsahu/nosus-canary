import 'package:flutter/material.dart';

class NoSusTheme {
  // Spacing Scale
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;

  // Corner Radii
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;

  // Colors - Light
  static const Color lBackground = Color(0xFFF5F5F3);
  static const Color lCard = Color(0xFFFFFFFF);
  static const Color lText = Color(0xFF111111);
  static const Color lBorder = Color(0xFF1A1A1A);
  static const Color lTextSecondary = Color(0xFF666666);

  // Colors - Dark
  static const Color dBackground = Color(0xFF0D0D0D);
  static const Color dCard = Color(0xFF151515);
  static const Color dText = Color(0xFFF5F5F5);
  static const Color dBorder = Color(0x33FFFFFF); // #FFFFFF20
  static const Color dTextSecondary = Color(0xFF999999);

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -1.0,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: primary,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: secondary,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: primary,
        letterSpacing: 0.5,
      ),
    );
  }

  // Light ThemeData
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lBackground,
      colorScheme: const ColorScheme.light(
        surface: lCard,
        onSurface: lText,
        primary: lText,
        onPrimary: lCard,
        outline: lBorder,
        outlineVariant: lBorder,
      ),
      textTheme: _textTheme(lText, lTextSecondary),
      cardTheme: CardThemeData(
        color: lCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: const BorderSide(color: lBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lText),
        centerTitle: false,
      ),
      pageTransitionsTheme: _fadeThroughTransitionsTheme,
    );
  }

  // Dark ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dBackground,
      colorScheme: const ColorScheme.dark(
        surface: dCard,
        onSurface: dText,
        primary: dText,
        onPrimary: dBackground,
        outline: dBorder,
        outlineVariant: dBorder,
      ),
      textTheme: _textTheme(dText, dTextSecondary),
      cardTheme: CardThemeData(
        color: dCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r16),
          side: const BorderSide(color: dBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: dText),
        centerTitle: false,
      ),
      pageTransitionsTheme: _fadeThroughTransitionsTheme,
    );
  }

  /// Shared fade-through transition for every platform, applied to all
  /// pushed `MaterialPageRoute`s app-wide via [ThemeData.pageTransitionsTheme]
  /// so no individual navigation call site needs to change.
  static const PageTransitionsTheme _fadeThroughTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    },
  );

  // Common UI styles and decorators
  static BoxDecoration cardDecoration(BuildContext context, {double radius = r16, Color? color}) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: theme.colorScheme.outline,
        width: 1.2,
      ),
    );
  }

  static BoxDecoration buttonDecoration(BuildContext context, {double radius = r12, Color? color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? dCard : lCard),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: theme.colorScheme.outline,
        width: 1.2,
      ),
    );
  }

  /// Returns platform-aware scroll physics (Clamping for Android/Web, Bouncing for iOS).
  static ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android || platform == TargetPlatform.fuchsia) {
      return const ClampingScrollPhysics();
    }
    return const BouncingScrollPhysics();
  }
}
