import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/providers/theme_provider.dart';
import 'package:no_sus/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The signed-out surface.
///
/// Before this, `AuthGate` rendered `AuthScreen` the instant `user == null`, so
/// the first thing anyone ever saw was an email field with no explanation of
/// what they were signing up for and no way to try any part of the product.
/// These tests pin the replacement: the tools that genuinely need no account
/// are reachable, and both auth routes are offered rather than assumed.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpWelcome(WidgetTester tester) async {
    // The screen is one lazy ListView, so the default 800x600 test surface
    // builds only the header and nothing below the fold. A tall viewport
    // materialises the whole page so the assertions below test content rather
    // than scroll position.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    // The cards use flutter_animate entrance effects, which leave pending
    // timers that fail the test unless they are run to completion.
    await tester.pumpAndSettle();
  }

  testWidgets('offers the no-account tools before asking anyone to sign up', (
    tester,
  ) async {
    await pumpWelcome(tester);

    expect(find.text('TRY IT NOW — NO ACCOUNT NEEDED'), findsOneWidget);
    expect(find.text('Send a Burn Note'), findsOneWidget);
    expect(find.text('Send a Burn File'), findsOneWidget);
    expect(find.text('Redeem a code'), findsOneWidget);
  });

  testWidgets('explains what an account adds rather than just gating', (
    tester,
  ) async {
    await pumpWelcome(tester);

    expect(find.text('WITH A FREE ACCOUNT'), findsOneWidget);
    expect(find.text('Study groups'), findsOneWidget);
    expect(find.text('Secure documents'), findsOneWidget);
    expect(find.text('Activity log'), findsOneWidget);
  });

  testWidgets('offers both sign-up and sign-in', (tester) async {
    await pumpWelcome(tester);

    expect(find.text('CREATE A FREE ACCOUNT'), findsOneWidget);
    expect(find.text('I ALREADY HAVE AN ACCOUNT'), findsOneWidget);
  });

  testWidgets('help is reachable without an account', (tester) async {
    await pumpWelcome(tester);

    // A confused visitor often cannot get past the thing confusing them, so
    // Help must not sit behind the auth wall.
    expect(find.widgetWithText(TextButton, 'What is NO SUS?'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
  });

  testWidgets('the guest tool cards carry screen-reader labels', (
    tester,
  ) async {
    // AGENTS.md §7: a bare GestureDetector announces nothing. These cards are
    // the primary calls to action on the app's first screen.
    await pumpWelcome(tester);

    // Matched on the Semantics widget's own properties rather than through
    // find.bySemanticsLabel — the same approach the existing auth/groups
    // regression tests use, because the rendered semantics tree does not
    // resolve reliably in this codebase (AGENTS.md §7).
    final labelled = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.label?.contains('Send a Burn Note') ?? false)
        .toList();

    expect(labelled, isNotEmpty, reason: 'the card must announce itself');
    expect(labelled.first.properties.button, isTrue);
  });
}
