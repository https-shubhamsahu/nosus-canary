import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/debug_logger.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  // Mock fallback mode has no Supabase client at all; touching
  // Supabase.instance there throws and would take the whole tree down. The
  // repository's own _isLive check then makes every call a no-op.
  final client = SupabaseService.instance.isConfigured
      ? Supabase.instance.client
      : null;
  if (client == null) {
    throw StateError('Notifications require a configured Supabase client');
  }
  return NotificationRepository(client);
});

/// The inbox. Re-subscribes on sign-in/sign-out so one account never sees
/// another's notifications after a session change on a shared device.
final notificationInboxProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || !SupabaseService.instance.isConfigured) {
    return Stream.value(const <AppNotification>[]);
  }
  return ref.watch(notificationRepositoryProvider).watchInbox();
});

/// Unread count for the header badge.
///
/// Derived with `.select` so the badge rebuilds only when the number actually
/// changes — not on every realtime emission of an unchanged list.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(
    notificationInboxProvider.select(
      (async) => async.value?.where((n) => n.isUnread).length ?? 0,
    ),
  );
});

/// Per-category preferences, with optimistic writes.
class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null || !SupabaseService.instance.isConfigured) {
      return NotificationPreferences.allOn;
    }
    return ref.read(notificationRepositoryProvider).fetchPreferences();
  }

  /// Flips one category.
  ///
  /// Optimistic, then reverted on failure. A switch that visibly springs back
  /// is a clearer signal that nothing was saved than a switch that stays put
  /// while the server disagrees — this setting decides whether someone hears
  /// about a security event, so silently diverging is the worst outcome.
  Future<void> setCategory(NotificationCategory category, bool enabled) async {
    final current = state.value ?? NotificationPreferences.allOn;
    final updated = current.withCategory(category, enabled);
    state = AsyncValue.data(updated);

    try {
      await ref.read(notificationRepositoryProvider).savePreferences(updated);
    } catch (e) {
      debugLog('NO SUS: Could not save notification preferences: $e');
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >(NotificationPreferencesNotifier.new);
