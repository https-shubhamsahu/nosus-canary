import 'package:flutter/material.dart';

import '../../../theme.dart';

/// NO SUS Canary "paper, ink and orange" theme: solid colours only, thick ink
/// outlines, orange as the one action colour. Orange is used for fills and
/// outlines, never for text on paper (it fails contrast there).
class CanaryPaper {
  static const Color paper = Color(0xFFFAF6EC);
  static const Color card = Color(0xFFFFFDF7);
  static const Color ink = Color(0xFF141414);
  static const Color inkSoft = Color(0xFF4A4740);
  static const Color orange = Color(0xFFF28C28);

  static const BorderSide line = BorderSide(color: ink, width: 2);
  static const BorderSide thick = BorderSide(color: ink, width: 2.5);

  static RoundedRectangleBorder _shape(double r, [BorderSide side = thick]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side);

  static ButtonStyle _solid({required Color bg, required Color fg}) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? bg.withValues(alpha: 0.45) : bg,
    ),
    foregroundColor: WidgetStateProperty.all(fg),
    overlayColor: WidgetStateProperty.all(ink.withValues(alpha: 0.08)),
    elevation: WidgetStateProperty.all(0),
    minimumSize: WidgetStateProperty.all(const Size(48, 52)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    ),
    shape: WidgetStateProperty.all(_shape(14)),
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
    ),
    animationDuration: const Duration(milliseconds: 160),
  );

  static ThemeData theme() {
    final base = NoSusTheme.lightTheme;
    const scheme = ColorScheme.light(
      surface: card,
      onSurface: ink,
      primary: orange,
      onPrimary: ink,
      secondary: ink,
      onSecondary: paper,
      tertiary: orange,
      onTertiary: ink,
      outline: ink,
      outlineVariant: ink,
      surfaceContainerHighest: orange,
      surfaceContainerHigh: card,
      surfaceContainer: card,
      surfaceContainerLow: card,
      surfaceContainerLowest: card,
      onSurfaceVariant: inkSoft,
      error: Color(0xFFB3261E),
    );
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: scheme,
      canvasColor: paper,
      dividerColor: ink,
      dividerTheme: const DividerThemeData(color: ink, thickness: 2),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: inkSoft),
      ),
      iconTheme: const IconThemeData(color: ink),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _shape(18),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        shape: Border(bottom: line),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _solid(bg: orange, fg: ink)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _solid(bg: orange, fg: ink)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _solid(bg: card, fg: ink).copyWith(
          side: WidgetStateProperty.all(thick),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(ink),
          overlayColor: WidgetStateProperty.all(orange.withValues(alpha: 0.25)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: orange,
              decorationThickness: 3,
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(ink),
          overlayColor: WidgetStateProperty.all(orange.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        floatingLabelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w800),
        hintStyle: const TextStyle(color: inkSoft),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: line,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: line,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: orange, width: 3),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: orange,
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        side: line,
        shape: _shape(12, line),
        checkmarkColor: ink,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? orange : card,
          ),
          foregroundColor: WidgetStateProperty.all(ink),
          side: WidgetStateProperty.all(line),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: orange,
        linearTrackColor: card,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: paper, fontWeight: FontWeight.w700),
        actionTextColor: orange,
        behavior: SnackBarBehavior.floating,
        shape: _shape(12, const BorderSide(color: orange, width: 2)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: _shape(20),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: paper),
      ),
      listTileTheme: const ListTileThemeData(iconColor: ink, textColor: ink),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(ink),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? orange : card,
        ),
        trackOutlineColor: WidgetStateProperty.all(ink),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: Color(0x66F28C28),
        selectionHandleColor: orange,
      ),
    );
  }
}
