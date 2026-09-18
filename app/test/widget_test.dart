import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/main.dart';

void main() {
  testWidgets('builds the NO SUS application shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'NO SUS');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
