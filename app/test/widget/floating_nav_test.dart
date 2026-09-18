import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/components/floating_nav.dart';

void main() {
  testWidgets('uses an icon-only footer on compact phone widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 700)),
          child: Scaffold(
            body: Stack(
              children: [FloatingNav(currentIndex: 2, onTap: (_) {})],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Study Desk'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Study Desk tab' &&
            widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps labels on wider layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(600, 700)),
          child: Scaffold(
            body: Stack(
              children: [FloatingNav(currentIndex: 0, onTap: (_) {})],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Study Desk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
