import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/monad/presentation/monad_screen.dart';
import 'package:no_sus/features/monad/presentation/monad_providers.dart';

void main() {
  testWidgets('Monad remains visibly unavailable without threshold evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MonadScreen())),
    );
    expect(monadThresholdVerified, isFalse);
    expect(
      find.text('Encrypted Monad sharing is not available yet'),
      findsOneWidget,
    );
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send with a Monad receipt'),
    );
    expect(send.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
