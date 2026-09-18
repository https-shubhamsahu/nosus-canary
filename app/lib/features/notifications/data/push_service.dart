import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/debug_logger.dart';
import '../../../services/supabase_service.dart';

/// Push token lifecycle: acquire, register, refresh, release.
///
/// **This has never been exercised against a real Firebase project.** There is
/// no `google-services.json` in the repo, so `Firebase.initializeApp()` throws
/// and [initialize] returns false, leaving every method here a no-op. The
/// in-app inbox works regardless — it reads the same `notifications` rows
/// straight from Postgres — so the product degrades to "notifications you see
/// when you open the app" rather than breaking.
///
/// Written this way deliberately: NO SUS already carries one never-exercised
/// security scaffold (Play Integrity, AGENTS.md §8), and the lesson from it is
/// that a scaffold must fail loudly closed and never pretend to work. Nothing
/// here reports success it did not achieve.
///
/// To provision: create the Firebase project, drop `google-services.json` into
/// `android/app/`, and set FCM_SERVICE_ACCOUNT_EMAIL / FCM_PRIVATE_KEY /
/// FCM_PROJECT_ID / PUSH_SWEEP_SECRET as Supabase secrets. No code change.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;
  bool _available = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  /// True only when Firebase initialised *and* a token was obtained.
  bool get isAvailable => _available;

  /// The token currently registered server-side, if any.
  String? get token => _token;

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  /// Brings up Firebase if it is configured. Safe to call repeatedly.
  ///
  /// Does **not** request the notification permission — that is a separate,
  /// contextual decision made by the UI (see NotificationPermissionPrompt).
  /// Initialising and asking are deliberately decoupled so the permission
  /// dialog never fires as a side effect of app start.
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _available = true;
      debugLog('NO SUS: Firebase initialised — push transport available.');
    } catch (e) {
      // Overwhelmingly the expected path today: no Firebase config present.
      _available = false;
      debugLog('NO SUS: Push unavailable (Firebase not configured): $e');
      return false;
    }

    // Tokens rotate — on app restore, reinstall, or at Google's discretion. A
    // rotated token that is not re-registered is a device that silently stops
    // receiving anything, which looks exactly like "notifications are broken".
    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (fresh) async {
        _token = fresh;
        await _registerToken(fresh);
      },
      onError: (Object e) => debugLog('NO SUS: Token refresh stream error: $e'),
    );

    return true;
  }

  /// Whether the OS will currently deliver notifications to this app.
  Future<bool> hasPermission() async {
    if (!_available) return false;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system permission dialog, then registers a token if granted.
  ///
  /// Android only ever shows this once; a second call after a denial returns
  /// the previous answer without any UI. That is why callers must explain the
  /// value *before* getting here — there is no second chance to ask well.
  Future<bool> requestPermissionAndRegister() async {
    if (!await initialize()) return false;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) {
        debugLog(
          'NO SUS: Notification permission not granted '
          '(${settings.authorizationStatus}).',
        );
        return false;
      }

      return await registerCurrentDevice();
    } catch (e) {
      debugLog('NO SUS: Permission request failed: $e');
      return false;
    }
  }

  /// Fetches this device's token and records it against the signed-in account.
  Future<bool> registerCurrentDevice() async {
    if (!_available) return false;
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isReachable) {
      return false;
    }
    if (Supabase.instance.client.auth.currentUser == null) return false;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return false;
      _token = token;
      return await _registerToken(token);
    } catch (e) {
      debugLog('NO SUS: Could not obtain push token: $e');
      return false;
    }
  }

  Future<bool> _registerToken(String token) async {
    try {
      await Supabase.instance.client.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_platform': _platform},
      );
      return true;
    } catch (e) {
      debugLog('NO SUS: Device token registration failed: $e');
      return false;
    }
  }

  /// Releases this device's token on sign-out.
  ///
  /// Must run *before* the session is torn down: `unregister_device_token` is
  /// scoped by `auth.uid()`, so after sign-out the delete matches nothing and
  /// the next person to sign in on this handset would keep receiving the
  /// previous account's notifications until their own registration overwrote
  /// the row.
  Future<void> releaseCurrentDevice() async {
    final token = _token;
    _token = null;
    if (token == null || !_available) return;
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isReachable) {
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'unregister_device_token',
        params: {'p_token': token},
      );
    } catch (e) {
      debugLog('NO SUS: Device token release failed: $e');
    }
  }

  /// Foreground messages. Background/terminated delivery is handled by the OS.
  Stream<RemoteMessage> get onForegroundMessage =>
      _available ? FirebaseMessaging.onMessage : const Stream.empty();

  /// Fires when a notification is tapped and the app was already running.
  Stream<RemoteMessage> get onNotificationTap =>
      _available ? FirebaseMessaging.onMessageOpenedApp : const Stream.empty();

  /// The notification that launched the app from terminated, if any.
  Future<RemoteMessage?> initialMessage() async {
    if (!_available) return null;
    try {
      return await FirebaseMessaging.instance.getInitialMessage();
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  void disposeForTest() {
    _refreshSub?.cancel();
    _refreshSub = null;
    _initialized = false;
    _available = false;
    _token = null;
  }
}
