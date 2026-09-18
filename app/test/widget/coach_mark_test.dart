import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/components/coach_mark.dart';
import 'package:no_sus/core/providers/theme_provider.dart';
import 'package:no_sus/features/onboarding/presentation/providers/tour_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('keeps DONE on screen when the spotlight target is off-screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final padKey = GlobalKey();
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: _TipHost(padKey: padKey)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('This pad is yours alone'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final done = tester.getRect(find.text('DONE'));
    expect(done.bottom, lessThanOrEqualTo(700));
    expect(done.top, greaterThanOrEqualTo(0));
  });
}

class _TipHost extends ConsumerStatefulWidget {
  const _TipHost({required this.padKey});

  final GlobalKey padKey;

  @override
  ConsumerState<_TipHost> createState() => _TipHostState();
}

class _TipHostState extends ConsumerState<_TipHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CoachMarks.showSequence(context, ref, [
        CoachMarkStep(
          id: TourSteps.workspacePad,
          targetKey: widget.padKey,
          title: 'This pad is yours alone',
          body:
              'Nothing typed here is shared with any group. It saves as you type, and '
              'syncs to your account so it follows you between devices.',
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 900,
            left: 16,
            right: 16,
            child: Container(
              key: widget.padKey,
              height: 80,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
