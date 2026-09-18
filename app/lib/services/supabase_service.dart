import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../config/supabase_credentials.dart';
import 'audit_service.dart';
import '../core/utils/debug_logger.dart';

/// Service to handle all interactions with the live Supabase project.
///
/// Automatically provides an [isConfigured] flag to check if live credentials
/// are available, falling back gracefully to mock storage if not.
///
/// Also performs a DNS pre-flight check during [initialize] and exposes
/// [isReachable] — if the host can't be resolved, realtime streams are
/// skipped entirely to prevent infinite reconnect loops.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  /// True only if credentials are set AND the host was reachable at startup.
  bool _isReachable = false;

  /// Flag indicating if valid Supabase credentials are configured
  bool get isConfigured => SupabaseBootstrap.isConfigured;

  /// True if credentials are set AND a DNS lookup succeeded at startup.
  /// Use this (instead of [isConfigured]) before opening any realtime streams.
  bool get isReachable => _isReachable;

  /// Compatibility entry point while legacy services migrate to repositories.
  Future<void> initialize() async {
    if (!isConfigured) {
      debugLog(
        "SupabaseService: Credentials empty. Operating in offline mock fallback mode.",
      );
      return;
    }

    try {
      await SupabaseBootstrap.initialize();
      _isReachable = true;
      debugLog("SupabaseService: Client successfully initialized.");
    } catch (e) {
      debugLog("SupabaseService: Initialization error: $e");
      _isReachable = false;
    }
  }

  // ─── Google Drive Proxy Operations ──────────────────────────────────────────
  
  String get _driveProxyUrl =>
      '${SupabaseCredentials.url}/functions/v1/drive-proxy';

  String get _authHeader {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      return 'Bearer $token';
    }
    return 'Bearer ${SupabaseCredentials.anonKey}';
  }

  /// Deletes a secure file from Google Drive via Edge Function.
  Future<void> deleteGDriveFile(String fileId) async {
    if (!isConfigured) return;

    try {
      final response = await http.delete(
        Uri.parse('$_driveProxyUrl/delete?fileId=$fileId'),
        headers: {'Authorization': _authHeader},
      );
      if (response.statusCode != 200) {
        debugLog(
          "SupabaseService: Delete proxy failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugLog("SupabaseService: Delete proxy exception: $e");
    }
  }

  /// Downloads a file from the Google Drive proxy Edge Function.
  Future<Uint8List?> downloadGDriveFile(String fileId) async {
    if (!isConfigured) return null;

    try {
      final response = await http.get(
        Uri.parse('$_driveProxyUrl/download?fileId=$fileId'),
        headers: {'Authorization': _authHeader},
      );
      if (response.statusCode != 200) {
        debugLog(
          "SupabaseService: Download proxy failed: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugLog("SupabaseService: Download proxy exception: $e");
      return null;
    }
  }

  /// Fetches the Google Drive Service Account Email dynamically from the proxy.
  Future<String?> getServiceAccountEmail() async {
    if (!isConfigured) return null;

    try {
      final response = await http.get(
        Uri.parse('$_driveProxyUrl/info'),
        headers: {'Authorization': _authHeader},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['serviceAccountEmail'] as String?;
      } else {
        debugLog("SupabaseService: getServiceAccountEmail failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugLog("SupabaseService: getServiceAccountEmail exception: $e");
    }
    return null;
  }

  // ─── Audit Logging Operations ──────────────────────────────────────────────

  /// Streams the audit logs from Supabase ordered by creation time.
  Stream<List<Map<String, String>>> watchAuditLogs() {
    if (!isConfigured) return const Stream.empty();

    return Supabase.instance.client
        .from('audit_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) {
          return list.map((row) {
            final timeStr = row['created_at'] != null
                ? DateTime.parse(
                    row['created_at'] as String,
                  ).toLocal().toIso8601String().substring(11, 19)
                : 'Now';
            final eventType = row['event_type'] as String? ?? 'group_updated';
            final metadata = row['metadata'] as Map<String, dynamic>? ?? {};

            return {
              'time': timeStr,
              'event': AuditService.formatEventDescription(eventType, metadata),
              'status': AuditService.getEventStatus(eventType, metadata),
            };
          }).toList();
        })
        .handleError((e) {
          debugLog("SupabaseService: watchAuditLogs error: $e");
        });
  }

  // Group ids the signed-in user actually belongs to. `log_group_event` rejects
  // writes for any other group, and a locally persisted history entry (see
  // RecentlySavedItem.destinationId) keeps pointing at a group long after the
  // user has left it — which produced a stream of "Not a member of the study
  // group" failures on every document open. Cached per user with a short TTL so
  // a fresh join is picked up without a round-trip per event.
  Set<String>? _memberGroupIds;
  String? _memberGroupIdsUser;
  DateTime? _memberGroupIdsAt;
  static const _membershipTtl = Duration(minutes: 5);

  /// Group ids [userId] belongs to, or null when that could not be determined.
  /// Callers must fail *open* on null rather than drop the event — a transient
  /// network failure must never silently swallow a security audit record.
  Future<Set<String>?> _memberGroupIdsFor(String userId) async {
    final cached = _memberGroupIds;
    final cachedAt = _memberGroupIdsAt;
    if (cached != null &&
        _memberGroupIdsUser == userId &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _membershipTtl) {
      return cached;
    }

    try {
      final rows = await Supabase.instance.client
          .from('study_group_members')
          .select('group_id')
          .eq('user_id', userId);
      final ids = <String>{
        for (final row in rows)
          if (row['group_id'] != null) row['group_id'] as String,
      };
      _memberGroupIds = ids;
      _memberGroupIdsUser = userId;
      _memberGroupIdsAt = DateTime.now();
      return ids;
    } catch (e) {
      debugLog("SupabaseService: group membership lookup failed: $e");
      return null;
    }
  }

  /// Drops the cached membership set. Call after joining or leaving a group so
  /// the next audit event is evaluated against the new membership.
  void invalidateGroupMembershipCache() {
    _memberGroupIds = null;
    _memberGroupIdsUser = null;
    _memberGroupIdsAt = null;
  }

  /// Inserts a new audit log record inside Supabase database via secure RPC.
  Future<void> logEvent(
    String eventType, {
    required String groupId,
    String? fileId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConfigured) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final memberOf = await _memberGroupIdsFor(userId);
    if (memberOf != null && !memberOf.contains(groupId)) {
      debugLog(
        "SupabaseService: skipping '$eventType' for group $groupId — "
        "not a member, the RPC would reject it.",
      );
      return;
    }

    try {
      await Supabase.instance.client.rpc('log_group_event', params: {
        'p_group_id': groupId,
        'p_file_id': fileId,
        'p_event_type': eventType,
        'p_metadata': metadata ?? {},
      });
    } catch (e) {
      debugLog("SupabaseService: logEvent RPC failed: $e");
    }
  }

  /// Forwards a Play Integrity token to supabase/functions/verify-play-integrity
  /// for server-side verification against Google's API — a Postgres RPC can't
  /// make the outbound HTTPS call to Google itself, hence an edge function
  /// (via functions.invoke) rather than .rpc() like the other calls here.
  /// See [PlayIntegrityService] — this is unreachable while
  /// AppIntegrityConfig.enabled is false.
  Future<Map<String, dynamic>?> verifyPlayIntegrityToken({
    required String token,
    required String nonce,
  }) async {
    if (!isConfigured) return null;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-play-integrity',
        body: {'token': token, 'nonce': nonce},
      );
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      debugLog("SupabaseService: verifyPlayIntegrityToken failed: $e");
      return null;
    }
  }

  /// Logs a device/session-level integrity finding (root, active
  /// instrumentation, risk flag) to the self-scoped `device_integrity_events`
  /// hash chain — separate from [logEvent] because these aren't tied to a
  /// specific study group.
  Future<void> logDeviceIntegrityEvent({
    required String eventType,
    required String deviceId,
    String severity = 'info',
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConfigured) return;

    try {
      await Supabase.instance.client.rpc('log_device_integrity_event', params: {
        'p_event_type': eventType,
        'p_severity': severity,
        'p_device_id': deviceId,
        'p_metadata': metadata ?? {},
      });
    } catch (e) {
      debugLog("SupabaseService: logDeviceIntegrityEvent RPC failed: $e");
    }
  }

  /// Realtime stream of a single user's `user_risk_state` row (see
  /// [RiskEngineService]). Filters explicitly to [userId] rather than
  /// relying on RLS alone, since a super-admin's RLS grant would otherwise
  /// let this stream return every user's row.
  Stream<Map<String, dynamic>?> watchMyRiskState(String userId) {
    if (!isConfigured) return Stream.value(null);

    return Supabase.instance.client
        .from('user_risk_state')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.isEmpty ? null : rows.first)
        .handleError((e) {
          debugLog("SupabaseService: watchMyRiskState error: $e");
        });
  }

  /// Clears the caller's own require_reauth/session_locked flags after a
  /// fresh sign-in. See acknowledge_reauth() in
  /// supabase/migrations/20260710030000_risk_engine.sql.
  Future<void> acknowledgeReauth() async {
    if (!isConfigured) return;
    await Supabase.instance.client.rpc('acknowledge_reauth');
  }

  /// Recent, unacknowledged security alerts visible to the caller under
  /// RLS — group admins see alerts for their groups, super-admins see all,
  /// everyone sees their own. Used by the admin-facing alerts list, not by
  /// the flagged user's own device.
  Future<List<Map<String, dynamic>>> fetchSecurityAlerts() async {
    if (!isConfigured) return [];
    try {
      final rows = await Supabase.instance.client
          .from('security_alerts')
          .select()
          .eq('acknowledged', false)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugLog("SupabaseService: fetchSecurityAlerts failed: $e");
      return [];
    }
  }

  /// Dismisses an alert from the admin/owner queue. See
  /// acknowledge_security_alert() in the migration for the server-side
  /// authorization check (group admin or super-admin only).
  Future<void> acknowledgeSecurityAlert(String alertId) async {
    if (!isConfigured) return;
    await Supabase.instance.client.rpc('acknowledge_security_alert', params: {
      'p_alert_id': alertId,
    });
  }

  /// Records that this device is active for the current user, and flags
  /// 'multiple_device_access' in the device-integrity ledger the first time
  /// a *new* device shows up for an account that already has another known
  /// device (never on a user's first-ever device). See
  /// register_device_seen() in 20260710040000_multi_device_detection.sql.
  Future<void> registerDeviceSeen(String deviceId) async {
    if (!isConfigured) return;
    await Supabase.instance.client.rpc('register_device_seen', params: {
      'p_device_id': deviceId,
    });
  }

  /// Carries a device's history from its legacy random-UUID id onto the
  /// hardware-backed one, so switching id formats doesn't make every
  /// already-known device look new (which would fire a false
  /// 'multiple_device_access' for every multi-device user on upgrade). See
  /// migrate_device_id() in 20260725000000_hardware_backed_device_id.sql.
  ///
  /// Returns false on any failure so the caller can leave the migration flag
  /// unset and retry on a later launch — never throws, since this runs on the
  /// post-sign-in path and must not break it.
  Future<bool> migrateDeviceId({
    required String oldDeviceId,
    required String newDeviceId,
  }) async {
    if (!isConfigured) return false;
    try {
      await Supabase.instance.client.rpc('migrate_device_id', params: {
        'p_old_device_id': oldDeviceId,
        'p_new_device_id': newDeviceId,
      });
      return true;
    } catch (e) {
      debugLog("SupabaseService: migrateDeviceId RPC failed: $e");
      return false;
    }
  }

  /// Fetches private notes for a user.
  Future<String> fetchUserNote(String userId) async {
    if (!isConfigured) return '';
    try {
      final response = await Supabase.instance.client
          .from('user_notes')
          .select('note_text')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['note_text'] as String? ?? 
          "Welcome to the NO SUS Secure Workspace!\n\n"
          "Quick Tutorial on Groups:\n"
          "1. Open the 'Groups' tab from the bottom nav.\n"
          "2. Tap the '+' icon to create a secure study group.\n"
          "3. Share the invite code with classmates.\n"
          "4. Upload notes — they are stored securely in the workspace.\n"
          "5. Use 'REVEAL' to read in our screenshot-proof viewer.";
    } catch (e) {
      debugLog("SupabaseService: fetchUserNote error: $e");
      return '';
    }
  }

  /// Saves private notes for a user.
  Future<void> saveUserNote(String userId, String noteText) async {
    if (!isConfigured) return;
    try {
      await Supabase.instance.client.from('user_notes').upsert({
        'user_id': userId,
        'note_text': noteText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugLog("SupabaseService: saveUserNote error: $e");
    }
  }

  /// Fetches focus logs from the last 7 days for a user.
  Future<Map<DateTime, int>> fetchFocusLogs(String userId) async {
    if (!isConfigured) return {};
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final response = await Supabase.instance.client
          .from('focus_logs')
          .select('date, focus_minutes')
          .eq('user_id', userId)
          .gte('date', sevenDaysAgo);

      final Map<DateTime, int> logs = {};
      for (final row in response) {
        final date = DateTime.parse(row['date'] as String);
        final minutes = row['focus_minutes'] as int? ?? 0;
        logs[DateTime(date.year, date.month, date.day)] = minutes;
      }
      return logs;
    } catch (e) {
      debugLog("SupabaseService: fetchFocusLogs error: $e");
      return {};
    }
  }

  /// Increments daily study focus minutes for a user.
  Future<void> incrementFocusMinutes(String userId, int minutes) async {
    if (!isConfigured) return;
    try {
      final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
      final existing = await Supabase.instance.client
          .from('focus_logs')
          .select('focus_minutes')
          .eq('user_id', userId)
          .eq('date', todayStr)
          .maybeSingle();

      final currentMinutes = existing?['focus_minutes'] as int? ?? 0;
      await Supabase.instance.client.from('focus_logs').upsert({
        'user_id': userId,
        'date': todayStr,
        'focus_minutes': currentMinutes + minutes,
      }, onConflict: 'user_id,date');
    } catch (e) {
      debugLog("SupabaseService: incrementFocusMinutes error: $e");
    }
  }

  /// Fetches daily count of security checks / logs from the last 7 days.
  Future<Map<DateTime, int>> fetchAuditLogCounts() async {
    if (!isConfigured) return {};
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final response = await Supabase.instance.client
          .from('audit_logs')
          .select('created_at')
          .gte('created_at', sevenDaysAgo);

      final Map<DateTime, int> counts = {};
      for (final row in response) {
        final date = DateTime.parse(row['created_at'] as String).toLocal();
        final dayKey = DateTime(date.year, date.month, date.day);
        counts[dayKey] = (counts[dayKey] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugLog("SupabaseService: fetchAuditLogCounts error: $e");
      return {};
    }
  }

  /// Fetches the profile of a user. If it doesn't exist, returns default values.
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    if (!isConfigured) return {};
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('display_name, avatar_color_start, avatar_color_end, onboarding_completed, survey_goals, survey_features, survey_user_type')
          .eq('id', userId)
          .maybeSingle();
      return response ?? {};
    } catch (e) {
      debugLog("SupabaseService: fetchProfile error: $e");
      return {};
    }
  }

  /// Updates or inserts a profile.
  Future<void> saveProfile({
    required String userId,
    required String email,
    required String displayName,
    required String avatarColorStart,
    required String avatarColorEnd,
    bool onboardingCompleted = true,
  }) async {
    if (!isConfigured) return;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'email': email,
        'display_name': displayName,
        'avatar_color_start': avatarColorStart,
        'avatar_color_end': avatarColorEnd,
        'onboarding_completed': onboardingCompleted,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugLog("SupabaseService: saveProfile error: $e");
    }
  }

  /// Updates only the survey data fields in the user's profile.
  Future<void> updateSurveyData({
    required String userId,
    required List<String> goals,
    required List<String> features,
    required String userType,
  }) async {
    if (!isConfigured) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'survey_goals': goals,
        'survey_features': features,
        'survey_user_type': userType,
      }).eq('id', userId);
    } catch (e) {
      debugLog("SupabaseService: updateSurveyData error: $e");
    }
  }

  /// Resolves the group_id for a file by its storage/file ID.
  /// Used by ZeroTrustGateway to check access for live Supabase files
  /// that are not in the static mock note list.
  Future<String?> getFileGroupId(String fileId) async {
    if (!isConfigured) return null;
    try {
      final response = await Supabase.instance.client
          .from('secure_files')
          .select('group_id')
          .eq('id', fileId)
          .maybeSingle();
      return response?['group_id'] as String?;
    } catch (e) {
      debugLog("SupabaseService: getFileGroupId error: $e");
      return null;
    }
  }
}

