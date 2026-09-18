import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:no_sus/features/auth/presentation/controllers/auth_controller.dart';
import 'package:no_sus/features/auth/presentation/screens/auth_screen.dart';

class MockAuthController extends Notifier<AsyncValue<void>> with Mock implements AuthController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);
}

void main() {
  group('AuthScreen Widget Tests', () {
    testWidgets('renders sign in screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => MockAuthController()),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify essential UI elements are present
      expect(find.text('NO SUS'), findsOneWidget);
      expect(find.text('See who opened it'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and Password
      expect(find.text('ENTER WORKSPACE'), findsOneWidget);
      expect(find.text('NEW TO WORKSPACE? SIGN UP'), findsOneWidget);
    });

    testWidgets('toggles to sign up mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => MockAuthController()),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'NEW TO WORKSPACE? SIGN UP'
      await tester.ensureVisible(find.text('NEW TO WORKSPACE? SIGN UP'));
      await tester.tap(find.text('NEW TO WORKSPACE? SIGN UP'));
      await tester.pumpAndSettle();

      // Verify UI changes to sign up mode
      expect(find.text('REGISTER'), findsOneWidget);
      expect(find.text('ALREADY REGISTERED? SIGN IN'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields on submit', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => MockAuthController()),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'ENTER WORKSPACE' without entering anything
      await tester.tap(find.text('ENTER WORKSPACE'));
      await tester.pumpAndSettle(); // Pump for validation and animations

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('main action button is announced as a labeled button to screen readers', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => MockAuthController()),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checks the Semantics widget's own configuration directly — a
      // regression guard against silently losing the button:true/label
      // wrapping this widget relies on for screen-reader announcement.
      final finder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Enter workspace',
      );
      expect(finder, findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(finder);
      expect(semanticsWidget.properties.button, isTrue);
    });
  });
}
