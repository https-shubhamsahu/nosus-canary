import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/providers/theme_provider.dart';
import 'package:no_sus/features/canary/presentation/canary_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests draw text in a placeholder font whose glyphs are full
/// squares, which makes the pixel-font labels measure about twice their real
/// width. Load the real bundled fonts so layout checks match the browser.
Future<void> _loadFonts() async {
  const families = {
    'Outfit': ['Outfit-Regular', 'Outfit-SemiBold', 'Outfit-Bold'],
    'Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
    'VT323': ['VT323-Regular'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/google_fonts/$file.ttf'));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Phone, small laptop, common laptop, the nav breakpoint, full HD.
  // Any RenderFlex overflow fails the test.
  for (final size in const [
    Size(390, 844),
    Size(1200, 800),
    Size(1366, 768),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('CanaryApp opens Canary home with no back button at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CanaryApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Every reader gets their own copy.'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
