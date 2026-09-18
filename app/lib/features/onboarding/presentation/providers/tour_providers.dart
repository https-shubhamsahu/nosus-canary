import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';

/// Stable ids for every contextual tip in the app.
///
/// One id per tip rather than a single "tour completed" flag: tips are attached
/// to screens the user may reach in any order, or never. A user who lives in
/// Groups should not have burned their Vault tip by not visiting the Vault.
abstract final class TourSteps {
  static const workspaceTools = 'workspace_tools';
  static const workspacePad = 'workspace_pad';
  static const groupsCreate = 'groups_create';
  static const groupsJoin = 'groups_join';
  static const vaultReveal = 'vault_reveal';
  static const groupMembers = 'group_members';
  static const groupActivity = 'group_activity';
}

/// Which contextual tips have already been shown and dismissed on this device.
///
/// Persisted, because a tip that reappears on every launch stops being help and
/// starts being noise. Resettable from Help so the tour can be replayed.
class TourProgressNotifier extends Notifier<Set<String>> {
  static const _key = 'nosus_tour_seen';

  @override
  Set<String> build() {
    try {
      final stored = ref.watch(sharedPreferencesProvider).getStringList(_key);
      return stored == null ? <String>{} : stored.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  bool hasSeen(String stepId) => state.contains(stepId);

  Future<void> markSeen(Iterable<String> stepIds) async {
    final next = {...state, ...stepIds};
    if (next.length == state.length) return;
    state = next;
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setStringList(_key, next.toList(growable: false));
    } catch (_) {}
  }

  Future<void> resetAll() async {
    state = <String>{};
    try {
      await ref.read(sharedPreferencesProvider).remove(_key);
    } catch (_) {}
  }
}

final tourProgressProvider =
    NotifierProvider<TourProgressNotifier, Set<String>>(
      TourProgressNotifier.new,
    );

/// Master switch for contextual tips.
///
/// Separate from [tourProgressProvider] so "stop showing me tips" is one
/// durable decision rather than something the user has to re-express every time
/// a new screen introduces one.
class TipsEnabledNotifier extends Notifier<bool> {
  static const _key = 'nosus_tips_enabled';

  @override
  bool build() {
    try {
      return ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      await ref.read(sharedPreferencesProvider).setBool(_key, value);
    } catch (_) {}
  }
}

final tipsEnabledProvider = NotifierProvider<TipsEnabledNotifier, bool>(
  TipsEnabledNotifier.new,
);
