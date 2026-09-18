import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/debug_logger.dart';
import '../../../services/supabase_service.dart';
import '../domain/app_notification.dart';

/// Reads and writes the notification inbox and its preferences.
///
/// Everything here is a plain table read or an RPC — no push provider involved.
/// That separation is what lets the inbox keep working when FCM is not
/// configured, which is its state today.
class NotificationRepository {
  final SupabaseClient _client;

  const NotificationRepository(this._client);

  bool get _isLive =>
      SupabaseService.instance.isConfigured &&
      SupabaseService.instance.isReachable &&
      _client.auth.currentUser != null;

  /// Live inbox for the signed-in user, newest first.
  ///
  /// A realtime stream rather than a poll: a notification that shows up two
  /// minutes late has usually been overtaken by the thing it was announcing.
  /// The `.eq` filter is defence in depth — RLS already restricts these rows to
  /// their owner.
  Stream<List<AppNotification>> watchInbox() {
    if (!_isLive) return Stream.value(const []);

    final userId = _client.auth.currentUser!.id;
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(AppNotification.fromRow).toList())
        .handleError((Object e) {
          debugLog('NO SUS: Notification stream error: $e');
        });
  }

  Future<List<AppNotification>> fetchInbox() async {
    if (!_isLive) return const [];
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List)
          .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugLog('NO SUS: fetchInbox failed: $e');
      return const [];
    }
  }

  /// Marks [ids] read, or the whole inbox when [ids] is null.
  ///
  /// Goes through the RPC rather than an UPDATE because `notifications` has no
  /// UPDATE policy at all — clients must not be able to touch `pushed_at` and
  /// make the delivery sweep skip a row.
  Future<void> markRead({List<String>? ids}) async {
    if (!_isLive) return;
    try {
      await _client.rpc('mark_notifications_read', params: {'p_ids': ids});
    } catch (e) {
      debugLog('NO SUS: markRead failed: $e');
    }
  }

  Future<void> delete(String id) async {
    if (!_isLive) return;
    try {
      await _client.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugLog('NO SUS: notification delete failed: $e');
    }
  }

  /// Current per-category preferences.
  ///
  /// Falls back to all-on when no row exists — the same assumption
  /// `enqueue_notification` makes, so the UI never shows a state the server
  /// disagrees with.
  Future<NotificationPreferences> fetchPreferences() async {
    if (!_isLive) return NotificationPreferences.allOn;
    try {
      final row = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', _client.auth.currentUser!.id)
          .maybeSingle();
      if (row == null) return NotificationPreferences.allOn;
      return NotificationPreferences.fromRow(row);
    } catch (e) {
      debugLog('NO SUS: fetchPreferences failed: $e');
      return NotificationPreferences.allOn;
    }
  }

  /// Persists the full preference set.
  ///
  /// Upsert rather than update: the row is created lazily by
  /// `register_device_token`, so a user who never granted the push permission
  /// has no row to update — and their in-app inbox preferences still need to
  /// stick. Throws so the caller can roll its optimistic UI back.
  Future<void> savePreferences(NotificationPreferences prefs) async {
    if (!_isLive) return;
    await _client.from('notification_preferences').upsert({
      'user_id': _client.auth.currentUser!.id,
      ...prefs.toColumns(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
