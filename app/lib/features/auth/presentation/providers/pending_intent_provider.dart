import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/utils/debug_logger.dart';

/// What the user was trying to do when an authentication wall interrupted them.
///
/// Persisted to SharedPreferences rather than held in memory: sign-up can round
/// trip through an email confirmation link or an OAuth browser hand-off, either
/// of which can take the process down. An intent that does not survive that is
/// an intent that gets dropped exactly when it matters most.
enum PendingIntentKind {
  /// Open a group invite landing page for [PendingIntent.payload] (invite code).
  joinGroup,

  /// Open a SecureSend share for [PendingIntent.payload] (share token).
  openShare,

  /// Land on the Groups tab — "I wanted to make/join a group".
  browseGroups,

  /// Land on the Vault tab — "I wanted to share a document".
  shareDocument;

  static PendingIntentKind? fromName(String? name) {
    for (final k in PendingIntentKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

class PendingIntent {
  final PendingIntentKind kind;
  final String? payload;

  const PendingIntent(this.kind, {this.payload});

  Map<String, dynamic> toJson() => {'kind': kind.name, 'payload': payload};

  static PendingIntent? fromJson(Map<String, dynamic> json) {
    final kind = PendingIntentKind.fromName(json['kind'] as String?);
    if (kind == null) return null;
    return PendingIntent(kind, payload: json['payload'] as String?);
  }

  @override
  bool operator ==(Object other) =>
      other is PendingIntent && other.kind == kind && other.payload == payload;

  @override
  int get hashCode => Object.hash(kind, payload);
}

/// Stores the action a signed-out user tried to take, so it can be replayed
/// once they have an account instead of dumping them on Home to find it again.
///
/// Deliberately a one-shot: [take] clears the stored value as it returns it, so
/// a resumed intent can never fire twice (e.g. a rebuild of the shell after the
/// join already happened).
class PendingIntentNotifier extends Notifier<PendingIntent?> {
  static const _key = 'nosus_pending_intent';

  /// The key the pre-existing invite flow wrote. Still read (never written) so
  /// an app updated mid-flow — invite saved by the old build, consumed by the
  /// new one — does not silently lose the user's invite.
  static const _legacyInviteKey = 'pending_invite_code';

  @override
  PendingIntent? build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);

      final legacy = prefs.getString(_legacyInviteKey);
      if (legacy != null && legacy.isNotEmpty) {
        return PendingIntent(PendingIntentKind.joinGroup, payload: legacy);
      }

      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return PendingIntent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugLog('NO SUS: Could not read pending intent: $e');
      return null;
    }
  }

  Future<void> set(PendingIntent intent) async {
    state = intent;
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(_key, jsonEncode(intent.toJson()));
    } catch (e) {
      debugLog('NO SUS: Could not persist pending intent: $e');
    }
  }

  /// Returns the stored intent and clears it in the same step.
  PendingIntent? take() {
    final current = state;
    if (current == null) return null;
    clear();
    return current;
  }

  void clear() {
    state = null;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.remove(_key);
      prefs.remove(_legacyInviteKey);
    } catch (_) {}
  }
}

final pendingIntentProvider =
    NotifierProvider<PendingIntentNotifier, PendingIntent?>(
      PendingIntentNotifier.new,
    );
