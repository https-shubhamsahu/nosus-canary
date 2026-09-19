import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'canary_home_screen.dart';
import 'ui/canary_strip.dart';

/// The standalone NO SUS Canary web app: Canary home is the root page.
/// No AuthGate, no workspace. Reader links (`#/canary/<id>?k=...`) are still
/// handled earlier in main() by CanaryReaderApp.
class CanaryApp extends StatelessWidget {
  const CanaryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NO SUS Canary',
    debugShowCheckedModeBanner: false,
    theme: CanaryTokens.theme(),
    darkTheme: CanaryTokens.theme(),
    themeMode: ThemeMode.dark,
    builder: (context, child) =>
        CanaryStrip(child: child ?? const SizedBox.shrink()),
    home: const CanaryHomeScreen(),
    // Old links to #/canary keep working and land on the same home page.
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const CanaryHomeScreen(),
    ),
  );
}
