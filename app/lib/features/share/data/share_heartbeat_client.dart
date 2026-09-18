import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';

/// Sends heartbeats and close events to the share-heartbeat Edge Function.
/// This is used by both the Web client and the native app viewer to log
/// how long the document was viewed.
class ShareHeartbeatClient {
  ShareHeartbeatClient._();
  static final ShareHeartbeatClient instance = ShareHeartbeatClient._();

  static final Uri _endpoint =
      Uri.parse('${SupabaseCredentials.url}/functions/v1/share-heartbeat');

  /// Sends a heartbeat tick or close signal for a given view event ID.
  ///
  /// [eventType], when provided, reports a web-viewer deterrent signal
  /// (devtools opened, repeated tab-visibility switches, a blocked
  /// copy/print/save/right-click attempt — see [WebSecurityGuard]) which
  /// the share-heartbeat function appends to that session's audit trail.
  Future<void> sendHeartbeat(
    String eventId, {
    bool close = false,
    String? eventType,
  }) async {
    try {
      await http.post(
        _endpoint,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseCredentials.anonKey,
        },
        body: jsonEncode({
          'view_event_id': eventId,
          'close': close,
          'event_type': eventType,
        }),
      );
    } catch (e) {
      // heartbeats are strictly best-effort, never throw errors back to user
    }
  }
}
