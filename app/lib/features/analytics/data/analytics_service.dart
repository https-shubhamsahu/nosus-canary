import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/debug_logger.dart';
import '../../../services/supabase_service.dart';

/// The complete set of events this app is allowed to record.
///
/// Mirrors the CHECK constraint in 20260730112308_analytics_events.sql — a name
/// that is not in both places is rejected by the database, on purpose. Add to
/// the migration first.
enum AnalyticsEvent {
  appOpened('app_opened'),
  welcomeViewed('welcome_viewed'),
  guestToolOpened('guest_tool_opened'),
  authWallHit('auth_wall_hit'),
  signupStarted('signup_started'),
  signupCompleted('signup_completed'),
  signinCompleted('signin_completed'),
  onboardingStarted('onboarding_started'),
  onboardingSkipped('onboarding_skipped'),
  onboardingCompleted('onboarding_completed'),
  intentResumed('intent_resumed'),
  groupCreateStarted('group_create_started'),
  groupCreateCompleted('group_create_completed'),
  groupJoinStarted('group_join_started'),
  groupJoinCompleted('group_join_completed'),
  firstDocumentUploaded('first_document_uploaded'),
  firstDocumentViewed('first_document_viewed'),
  burnNoteCreated('burn_note_created'),
  burnFileCreated('burn_file_created'),
  notificationPermissionPrompted('notification_permission_prompted'),
  notificationPermissionGranted('notification_permission_granted'),
  notificationPermissionDenied('notification_permission_denied'),
  tourStepShown('tour_step_shown'),
  tourSkipped('tour_skipped'),
  helpTopicOpened('help_topic_opened');

  final String wireName;
  const AnalyticsEvent(this.wireName);
}

/// Records activation-funnel events so friction can be measured.
///
/// Rules this service enforces so callers cannot get them wrong:
///
///   * **Fire and forget.** Every call returns immediately and swallows its
///     errors. Analytics must never delay a screen or surface a failure — a
///     user whose upload fails because a metric could not be written would be
///     an absurd trade.
///   * **No free-form strings.** [log] takes an enum and a small map of
///     primitives. Callers cannot pass a document name, a group name, an invite
///     code or a share token, because there is nowhere to put one — the
///     database caps and type-checks `properties` as a backstop.
///   * **Once-only events stay once-only.** [logOnce] is backed by
///     SharedPreferences, so `first_document_uploaded` means the user's first,
///     not the first this session.
///
/// See store_listing/data_safety_answers.md — this is the only thing in the app
/// that reports usage to the server.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _oncePrefix = 'nosus_analytics_once_';

  SharedPreferences? _prefs;
  String? _appVersion;
  bool _versionResolved = false;

  /// Injected at boot so [logOnce] does not have to await a plugin channel on
  /// every call. Safe to skip — the service just degrades to always logging.
  void attachPreferences(SharedPreferences prefs) => _prefs = prefs;

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  Future<String?> _resolveVersion() async {
    if (_versionResolved) return _appVersion;
    _versionResolved = true;
    try {
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      _appVersion = null;
    }
    return _appVersion;
  }

  /// Records [event]. Never throws, never blocks the caller.
  ///
  /// [properties] must contain only primitives (String/num/bool) and should be
  /// low-cardinality — "which tab", not "which file".
  void log(AnalyticsEvent event, {Map<String, Object?> properties = const {}}) {
    unawaited(_send(event, properties));
  }

  /// Records [event] at most once per install.
  ///
  /// Returns true if it was recorded, false if it had already fired. Used for
  /// the "first ever" milestones, which are meaningless if they repeat.
  Future<bool> logOnce(
    AnalyticsEvent event, {
    Map<String, Object?> properties = const {},
  }) async {
    final prefs = _prefs ?? await _loadPrefs();
    final key = '$_oncePrefix${event.wireName}';
    try {
      if (prefs?.getBool(key) == true) return false;
      await prefs?.setBool(key, true);
    } catch (_) {
      // Could not read the marker — log anyway. An occasional duplicate is a
      // better failure than losing the milestone entirely.
    }
    unawaited(_send(event, properties));
    return true;
  }

  Future<SharedPreferences?> _loadPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    return _prefs;
  }

  Future<void> _send(
    AnalyticsEvent event,
    Map<String, Object?> properties,
  ) async {
    // Mock fallback mode has no backend by design; unreachable means the DNS
    // pre-flight failed. Either way there is nothing to write to.
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isReachable) {
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client.from('analytics_events').insert({
        // Explicit rather than relying on a default: the RLS policies split on
        // exactly this value (authenticated must match auth.uid(); anon must be
        // null), so it has to be stated.
        'user_id': client.auth.currentUser?.id,
        'event': event.wireName,
        'properties': _sanitize(properties),
        'app_version': await _resolveVersion(),
        'platform': _platform,
      });
    } catch (e) {
      debugLog('NO SUS: analytics "${event.wireName}" not recorded: $e');
    }
  }

  /// Drops anything that is not a primitive and truncates long strings.
  ///
  /// Defence in depth against a future caller passing a whole object through:
  /// the database constraints would reject an oversized payload, but silently
  /// losing the event is worse than sending a trimmed one.
  Map<String, Object?> _sanitize(Map<String, Object?> properties) {
    final out = <String, Object?>{};
    for (final entry in properties.entries) {
      final value = entry.value;
      if (value is num || value is bool) {
        out[entry.key] = value;
      } else if (value is String) {
        out[entry.key] = value.length > 64 ? value.substring(0, 64) : value;
      }
    }
    return out;
  }
}
