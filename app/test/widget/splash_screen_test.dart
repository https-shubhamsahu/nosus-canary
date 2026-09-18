import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/screens/splash_screen.dart';

void main() {
  testWidgets('shows only the canonical wordmark on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: BrandSplash()));
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('NO SUS'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('brand-square-stop')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'NO SUS opening application',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the finished mark immediately with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: BrandSplash(),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('NO SUS'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('brand-square-stop')), findsOneWidget);
  });
}
