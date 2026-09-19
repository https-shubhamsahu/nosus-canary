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

/// Canary-only tokens. Do not reuse these on the rest of NO SUS.
class CanaryTokens {
  const CanaryTokens._();

  static const Color bg = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF141418);
  static const Color surfaceHi = Color(0xFF1C1C22);
  static const Color border = Color(0x14FFFFFF);
  static const Color text = Color(0xFFF5F5F7);
  static const Color textDim = Color(0xFF9A9AA5);
  static const Color canary = Color(0xFFF28C28);
  static const Color canaryHi = Color(0xFFFFB066);
  static const Color canaryDeep = Color(0xFFC9690F);
  static const Color onCanary = Color(0xFF1A0E02);
  static const Color monad = Color(0xFF836EF9);
  static const Color ok = Color(0xFF3DDC97);
  static const Color bad = Color(0xFFFF5A5F);
  static const Color warn = Color(0xFFF5C518);

  static const double rChip = 14;
  static const double rCard = 20;
  static const double rHero = 28;

  static const String displayFont = 'Outfit';
  static const String bodyFont = 'Inter';
  static const String monoFont = 'VT323';

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [canary, canaryHi],
  );

  static const LinearGradient chain = LinearGradient(
    colors: [canary, monad],
  );

  static List<BoxShadow> get glow => const [
    BoxShadow(
      color: Color(0x59F28C28),
      blurRadius: 32,
      spreadRadius: -8,
    ),
  ];

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      surface: surface,
      onSurface: text,
      primary: canary,
      onPrimary: onCanary,
      secondary: monad,
      onSecondary: text,
      error: bad,
      onError: text,
      outline: border,
      outlineVariant: border,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      fontFamily: bodyFont,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: displayFont,
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.05,
          letterSpacing: -1.2,
        ),
        displayMedium: TextStyle(
          fontFamily: displayFont,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: text,
          height: 1.1,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          fontFamily: displayFont,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontFamily: displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleMedium: TextStyle(
          fontFamily: displayFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleSmall: TextStyle(
          fontFamily: displayFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: text,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textDim,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textDim,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontFamily: displayFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: 1.2,
        ),
        labelSmall: TextStyle(
          fontFamily: monoFont,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: text,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: text,
        iconTheme: IconThemeData(color: text),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHi,
        labelStyle: const TextStyle(color: textDim),
        hintStyle: const TextStyle(color: textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rCard),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rCard),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rCard),
          borderSide: const BorderSide(color: canary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: canary,
          foregroundColor: onCanary,
          disabledBackgroundColor: canaryDeep,
          disabledForegroundColor: onCanary.withValues(alpha: 0.5),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rChip),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rChip),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: monad,
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x33836EF9),
        labelStyle: const TextStyle(
          fontFamily: monoFont,
          color: text,
          fontSize: 14,
        ),
        side: const BorderSide(color: monad),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rChip),
        ),
      ),
      dividerColor: border,
      focusColor: canaryHi.withValues(alpha: 0.35),
    );
  }
}
