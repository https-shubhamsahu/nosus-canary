import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/providers/theme_provider.dart';
import 'package:no_sus/features/auth/presentation/providers/pending_intent_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "preserve intent" contract: tap Join Community → hit the auth wall →
/// sign up → land back on the join flow, not on Home.
///
/// Persistence is the load-bearing part. Sign-up can round trip through an
/// email confirmation link or an OAuth browser hand-off, either of which can
/// take the process down, so an in-memory intent would be dropped exactly when
/// it matters most.
void main() {
  Future<ProviderContainer> container() async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('an intent survives a process restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await container();

    await first
        .read(pendingIntentProvider.notifier)
        .set(
          const PendingIntent(PendingIntentKind.joinGroup, payload: 'ABCD2345'),
        );

    final relaunched = await container();
    final restored = relaunched.read(pendingIntentProvider);

    expect(restored?.kind, PendingIntentKind.joinGroup);
    expect(restored?.payload, 'ABCD2345');
  });

  test('take() returns the intent once and clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    final notifier = c.read(pendingIntentProvider.notifier);

    await notifier.set(const PendingIntent(PendingIntentKind.browseGroups));

    expect(notifier.take()?.kind, PendingIntentKind.browseGroups);
    expect(
      notifier.take(),
      isNull,
      reason: 'a resumed intent must never fire twice on a rebuild',
    );

    // And the clear is durable, not just in memory.
    final relaunched = await container();
    expect(relaunched.read(pendingIntentProvider), isNull);
  });

  test('an invite parked by the previous build is still honoured', () async {
    // The old flow wrote this key directly. An app updated mid-flow — invite
    // saved by the old build, consumed by the new one — must not lose it.
    SharedPreferences.setMockInitialValues({'pending_invite_code': 'LEGACY99'});
    final c = await container();

    final restored = c.read(pendingIntentProvider);
    expect(restored?.kind, PendingIntentKind.joinGroup);
    expect(restored?.payload, 'LEGACY99');

    c.read(pendingIntentProvider.notifier).clear();

    final relaunched = await container();
    expect(
      relaunched.read(pendingIntentProvider),
      isNull,
      reason: 'clearing must remove the legacy key too, or it replays forever',
    );
  });

  test(
    'a corrupt stored intent is ignored rather than crashing boot',
    () async {
      SharedPreferences.setMockInitialValues({
        'nosus_pending_intent': 'not json at all',
      });
      final c = await container();
      expect(c.read(pendingIntentProvider), isNull);
    },
  );

  test('an intent kind this build does not know is ignored', () async {
    // Forward compatibility: a newer build could park a kind this one has never
    // heard of. Dropping it is correct; throwing during provider build is not.
    SharedPreferences.setMockInitialValues({
      'nosus_pending_intent': jsonEncode({
        'kind': 'somethingFromTheFuture',
        'payload': 'x',
      }),
    });
    final c = await container();
    expect(c.read(pendingIntentProvider), isNull);
  });
}
