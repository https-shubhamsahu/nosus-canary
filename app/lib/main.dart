import 'dart:async';
import 'features/monad/domain/monad_receipt.dart';
import 'features/monad/presentation/experiment_frame.dart';
import 'features/monad/presentation/monad_screen.dart';
import 'features/canary/domain/canary_link.dart';
import 'features/canary/presentation/canary_home_screen.dart';
import 'features/canary/presentation/canary_reader_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import 'config/crash_reporting_config.dart';
import 'theme.dart';
import 'features/profile/presentation/widgets/profile_avatar.dart';
import 'core/providers/theme_provider.dart';
import 'components/floating_nav.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/groups/screens/groups_screen.dart';
import 'features/groups/screens/group_invite_landing_screen.dart';
import 'features/workspace/presentation/pages/workspace_tab.dart';
import 'features/vault/presentation/pages/vault_tab.dart';
import 'features/vault/presentation/pages/study_desk_tab.dart';
import 'features/audit/presentation/pages/audit_tab.dart';

import 'services/supabase_service.dart';
import 'services/measure_reporting.dart';
import 'services/screenshot_guard.dart';
import 'services/audit_service.dart';
import 'services/device_integrity_service.dart';
import 'services/share_intent_service.dart';
import 'features/workspace/presentation/widgets/save_to_no_sus_dialog.dart';
import 'features/focus/providers/focus_provider.dart';
import 'core/utils/debug_logger.dart';
import 'features/share/presentation/screens/anonymous_share_viewer_screen.dart';
import 'features/share/presentation/screens/in_app_share_viewer_screen.dart';
import 'features/share/presentation/screens/share_analytics_screen.dart';
import 'features/share/presentation/providers/share_providers.dart';
import 'features/share/domain/entities/share_link.dart';

import 'package:app_links/app_links.dart';
import 'features/analytics/data/analytics_service.dart';
import 'features/auth/presentation/providers/pending_intent_provider.dart';
import 'features/notifications/data/push_service.dart';
import 'features/notifications/presentation/notification_router.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';
import 'features/notifications/presentation/screens/notification_inbox_screen.dart';
import 'features/config/data/remote_config_service.dart';
import 'features/config/presentation/providers/config_provider.dart';
import 'core/mascot/mascot_state.dart';
import 'core/mascot/mascot_view.dart';

import 'features/share/presentation/screens/burn_note_viewer_screen.dart';
import 'features/share/presentation/screens/burn_file_viewer_screen.dart';
import 'features/share/presentation/screens/redeem_code_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BurnNoteToken {
  final String id;
  final String keyHex;
  final String ivHex;
  BurnNoteToken({required this.id, required this.keyHex, required this.ivHex});
}

/// Public (rather than private) so the URL contract has regression tests —
/// see test/unit/deep_link_parsing_test.dart. Burn links are shared into the
/// wild; silently changing what parses is a production outage.
BurnNoteToken? extractBurnNoteToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();
  debugLog('NO SUS: Extracting Burn Note Token from: $fullUrl');

  // ── Format 1 (new): #/burn/<uuid>?k=<keyHex>&v=<ivHex> ─────────────────
  // Extract the hash fragment, then parse query params from within it.
  // e.g. https://nosus.foo/#/burn/abc-123?k=aaa...&v=bbb...
  final hashIdx = fullUrl.indexOf('#');
  if (hashIdx != -1) {
    final fragment = fullUrl.substring(hashIdx + 1); // /burn/<uuid>?k=...&v=...
    final qIdx = fragment.indexOf('?');
    if (qIdx != -1) {
      final path = fragment.substring(0, qIdx); // /burn/<uuid>
      final query = fragment.substring(qIdx + 1); // k=...&v=...
      final params = Uri.splitQueryString(query);
      final burnMatch = RegExp(
        r'burn/([a-f0-9\-]{36})',
        caseSensitive: false,
      ).firstMatch(path);
      final k = params['k'];
      final v = params['v'];
      if (burnMatch != null &&
          k != null &&
          v != null &&
          k.length == 64 &&
          v.length == 32) {
        debugLog(
          'NO SUS: Burn Note matched (new format) id=${burnMatch.group(1)}',
        );
        return BurnNoteToken(id: burnMatch.group(1)!, keyHex: k, ivHex: v);
      }
    }
  }

  // ── Format 2 (legacy): burn/<uuid>#<keyHex>.<ivHex> ─────────────────────
  final legacyRegExp = RegExp(
    r'burn/([a-f0-9\-]{36})(?:#|%23|/)([a-f0-9]{64})\.([a-f0-9]{32})',
    caseSensitive: false,
  );
  final match = legacyRegExp.firstMatch(fullUrl);
  if (match != null) {
    debugLog('NO SUS: Burn Note matched (legacy format) id=${match.group(1)}');
    return BurnNoteToken(
      id: match.group(1)!,
      keyHex: match.group(2)!,
      ivHex: match.group(3)!,
    );
  }

  debugLog('NO SUS: No Burn Note Token match in: $fullUrl');
  return null;
}

class BurnFileToken {
  final String id;
  final String keyHex;
  final String ivHex;
  BurnFileToken({required this.id, required this.keyHex, required this.ivHex});
}

/// Public for the same reason as [extractBurnNoteToken] — a regression here
/// silently breaks every Burn Files link already shared into the wild. Only
/// one URL format exists (no legacy format to carry, unlike burn notes).
/// e.g. https://nosus.foo/#/burnfile/abc-123?k=aaa...&v=bbb...
BurnFileToken? extractBurnFileToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();
  debugLog('NO SUS: Extracting Burn File Token from: $fullUrl');

  final hashIdx = fullUrl.indexOf('#');
  if (hashIdx == -1) return null;

  final fragment = fullUrl.substring(
    hashIdx + 1,
  ); // /burnfile/<uuid>?k=...&v=...
  final qIdx = fragment.indexOf('?');
  if (qIdx == -1) return null;

  final path = fragment.substring(0, qIdx); // /burnfile/<uuid>
  final query = fragment.substring(qIdx + 1); // k=...&v=...
  final params = Uri.splitQueryString(query);
  final match = RegExp(
    r'burnfile/([a-f0-9\-]{36})',
    caseSensitive: false,
  ).firstMatch(path);
  final k = params['k'];
  final v = params['v'];
  if (match != null &&
      k != null &&
      v != null &&
      k.length == 64 &&
      v.length == 32) {
    debugLog('NO SUS: Burn File matched id=${match.group(1)}');
    return BurnFileToken(id: match.group(1)!, keyHex: k, ivHex: v);
  }

  debugLog('NO SUS: No Burn File Token match in: $fullUrl');
  return null;
}

/// Multi-file Burn Files share — a NEW, additive link shape living on its
/// own `burnfiles` (plural) path so it can never collide with or change the
/// parsing of `burnfile/<uuid>` links already shared into the wild. Each
/// file keeps its own independent key/IV (the exact same per-file crypto as
/// [extractBurnFileToken] — no new crypto primitive, just N of them), so the
/// only new thing here is the list-shaped URL, not the encryption scheme.
/// e.g. https://app.nosus.foo/#/burnfiles/id1,id2?k=key1,key2&v=iv1,iv2
List<BurnFileToken>? extractBurnFilesToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();

  final hashIdx = fullUrl.indexOf('#');
  if (hashIdx == -1) return null;

  final fragment = fullUrl.substring(
    hashIdx + 1,
  ); // /burnfiles/<id,id,...>?k=...&v=...
  final qIdx = fragment.indexOf('?');
  if (qIdx == -1) return null;

  final path = fragment.substring(0, qIdx);
  final query = fragment.substring(qIdx + 1);
  final params = Uri.splitQueryString(query);

  final match = RegExp(
    r'burnfiles/([a-f0-9,\-]+)',
    caseSensitive: false,
  ).firstMatch(path);
  final ids = match?.group(1)?.split(',') ?? const [];
  final keys = params['k']?.split(',') ?? const [];
  final ivs = params['v']?.split(',') ?? const [];

  if (ids.isEmpty || ids.length != keys.length || ids.length != ivs.length) {
    return null;
  }
  final tokens = <BurnFileToken>[];
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final k = keys[i];
    final v = ivs[i];
    if (id.length != 36 || k.length != 64 || v.length != 32) return null;
    tokens.add(BurnFileToken(id: id, keyHex: k, ivHex: v));
  }
  debugLog('NO SUS: Burn Files batch matched, count=${tokens.length}');
  return tokens;
}

/// NO SUS Canary reader link: `#/canary/<uuid>?k=<64 hex key>`. Public so the
/// URL contract has regression tests (test/unit/canary_link_test.dart).
CanaryLinkToken? extractCanaryToken(Uri uri) {
  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();
  return parseCanaryReaderLink(fullUrl);
}

/// Extracts the opaque token carried by a two-digit redemption pairing link.
/// The token is deliberately long and unguessable; the two visible digits are
/// only a human confirmation step and must never be accepted on their own.
String? extractRedemptionToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final match = RegExp(
      r'^redeem/([a-f0-9]{64})(?:\?.*)?$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (match != null) return match.group(1)!.toLowerCase();
  }
  return null;
}

/// Extracts a SecureSend share token from a `/v/<token>` URL, checking both
/// the fragment (default hash-based web routing, e.g. `#/v/abc123`) and the
/// path, so the link works regardless of URL strategy. Returns null on any
/// other platform/URL shape — this only ever matches an intentional share link.
String? extractShareToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0] == 'v' && parts[1].isNotEmpty) {
      return parts[1];
    }
  }
  return null;
}

/// Extracts a group invite code from a URL/deep link, supporting hash routing
/// (#/join/abc123xyz), path routing (/join/abc123xyz), path segments, and custom scheme formats.
String? extractInviteToken(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0] == 'join' && parts[1].isNotEmpty) {
      return parts[1];
    }
  }
  if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
    return uri.pathSegments[1];
  }
  if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  return null;
}

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Crash reporting — no-op unless SENTRY_DSN is supplied via
      // --dart-define (see lib/config/crash_reporting_config.dart). Used at
      // the low-level `SentryFlutter.init(configure)` form (no `appRunner`)
      // so it slots into this existing bootstrap sequence instead of
      // requiring runApp() to move inside a callback. sendDefaultPii is
      // explicitly off and tracing defaults to 0% — this product's premise
      // is zero-knowledge/no-tracking, so crash capture stays scoped to
      // errors, not analytics.
      if (CrashReportingConfig.isEnabled) {
        await SentryFlutter.init((options) {
          options.dsn = CrashReportingConfig.sentryDsn;
          options.tracesSampleRate = CrashReportingConfig.tracesSampleRate;
          options.sendDefaultPii = false;
        });
      }
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (CrashReportingConfig.isEnabled) {
          Sentry.captureException(details.exception, stackTrace: details.stack);
        }
      };

      // Measure (measure.sh) — Android-only, and a no-op unless both
      // MEASURE_API_KEY and MEASURE_API_URL are supplied via --dart-define
      // (see lib/config/measure_reporting_config.dart, which also documents
      // what this SDK collects and the two behaviours that are hostile to this
      // product).
      //
      // Order is load-bearing: this must stay AFTER the FlutterError.onError
      // assignment above. Measure's init captures whatever handler is
      // installed at that instant and calls it after its own, so initialising
      // here chains Measure → Sentry → presentError. Move it earlier and the
      // assignment above silently overwrites Measure's handler, leaving the
      // SDK configured, reporting nothing, and looking fine.
      //
      // The empty callback is deliberate. Measure's documented form runs
      // runApp() inside init(), which this bootstrap cannot do — there are
      // several early-return runApp() branches below for share/burn deep
      // links. init() only awaits its own setup and then invokes the callback,
      // so a no-op is equivalent; same reasoning as the low-level
      // SentryFlutter.init form above.
      //
      // start() is explicit because both MeasureConfigs are set to
      // autoStart: false — one place where collection begins, and the point a
      // consent gate would attach.
      await initializeMeasureReporting();

      // Pre-load SharedPreferences synchronously before routing and app run
      final prefs = await SharedPreferences.getInstance();
      // Hand the warm instance to the analytics service so its "first ever"
      // milestones can be deduped without awaiting a plugin channel per call.
      AnalyticsService.instance.attachPreferences(prefs);

      // Initialize Supabase immediately so all early routing screens can access the client
      await SupabaseService.instance.initialize();

      // Funnel entry point. Fire-and-forget by construction — see
      // AnalyticsService; it no-ops entirely in mock fallback mode.
      AnalyticsService.instance.log(AnalyticsEvent.appOpened);

      // Do not probe `getUser()` and sign out during startup. Supabase Flutter
      // v2 restores a persisted session first and refreshes it asynchronously;
      // an expired access token or a transient network failure is normal here.
      // Treating either as proof of a deleted account was logging real users
      // out whenever they relaunched at the wrong moment.
      //
      // A genuinely invalid session emits the SDK's signed-out state, which
      // AuthGate already handles. This keeps restore fast and non-destructive.
      if (SupabaseService.instance.isConfigured) {
        unawaited(() async {
          final cachedSession = Supabase.instance.client.auth.currentSession;
          if (cachedSession?.isExpired ?? false) {
            debugLog(
              'NO SUS: Restoring an expired cached session; awaiting SDK refresh.',
            );
          }
        }());
      }

      // SecureSend anonymous path: a share-link recipient may have no NO SUS
      // account at all, so this branch skips Supabase/auth entirely and never
      // rejoins the normal app below.
      final shareToken = extractShareToken(Uri.base);
      if (shareToken != null) {
        // ProviderScope here is only so the mascot system (Riverpod) works on
        // this standalone entrypoint — it has no Supabase session and never
        // will; nothing mascot-related depends on one.
        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: AnonymousShareViewerScreen(token: shareToken),
          ),
        );
        return;
      }

      final burnNoteToken = extractBurnNoteToken(Uri.base);
      if (burnNoteToken != null) {
        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: BurnNoteViewerScreen(
              noteId: burnNoteToken.id,
              keyHex: burnNoteToken.keyHex,
              ivHex: burnNoteToken.ivHex,
            ),
          ),
        );
        return;
      }

      // Burn Files anonymous path — same "no session, never rejoins the
      // normal app" pattern as burn notes/SecureSend above. The recipient
      // never has a NO SUS account (product decision — see
      // supabase/migrations/20260710050000_burn_files.sql).
      final burnFileToken = extractBurnFileToken(Uri.base);
      if (burnFileToken != null) {
        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: BurnFileViewerScreen(
              files: [
                (
                  id: burnFileToken.id,
                  keyHex: burnFileToken.keyHex,
                  ivHex: burnFileToken.ivHex,
                ),
              ],
            ),
          ),
        );
        return;
      }

      // Multi-file share — checked after the single-file path so an old
      // `burnfile/<uuid>` link (no trailing 's') is never re-parsed here;
      // the two regexes are structurally disjoint (see extractBurnFilesToken).
      final burnFilesToken = extractBurnFilesToken(Uri.base);
      if (burnFilesToken != null) {
        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: BurnFileViewerScreen(
              files: burnFilesToken
                  .map((t) => (id: t.id, keyHex: t.keyHex, ivHex: t.ivHex))
                  .toList(),
            ),
          ),
        );
        return;
      }

      // NO SUS Canary reader path: anonymous and standalone, like Burn links.
      final canaryToken = extractCanaryToken(Uri.base);
      if (canaryToken != null) {
        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: CanaryReaderApp(
              noteId: canaryToken.noteId,
              keyHex: canaryToken.keyHex,
            ),
          ),
        );
        return;
      }

      final redemptionToken = extractRedemptionToken(Uri.base);
      if (redemptionToken != null) {
        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: RedeemCodeScreen(redeemToken: redemptionToken),
          ),
        );
        return;
      }

      // supabase_flutter runs its own app-link listener and consumes
      // `login-callback` itself. The PKCE code is single-use, so calling
      // getSessionFromUrl here unconditionally made both handlers race for it
      // and whichever lost reported `flow_state_not_found` — non-deterministic,
      // and it surfaced as an auth error on a login that had actually
      // succeeded. Wait for the SDK, and only recover manually if it never
      // establishes a session.
      Future<void> handleOAuthCallback(Uri uri) async {
        final auth = Supabase.instance.client.auth;
        if (auth.currentSession != null) return;

        try {
          await auth.onAuthStateChange
              .firstWhere((state) => state.session != null)
              .timeout(const Duration(seconds: 8));
          debugLog('NO SUS: OAuth callback completed by the Supabase SDK.');
          return;
        } catch (_) {
          debugLog(
            'NO SUS: SDK established no session for $uri — recovering manually.',
          );
        }

        try {
          await auth.getSessionFromUrl(uri);
          debugLog('NO SUS: Session recovered successfully!');
        } catch (e) {
          debugLog('NO SUS: Error recovering session from deep link: $e');
        }
      }

      // Listen to deep links for manual session recovery and invite codes
      final appLinks = AppLinks();
      appLinks.uriLinkStream.listen((uri) async {
        debugLog('NO SUS: Received Deep Link: $uri');
        final inviteCode = extractInviteToken(uri);
        if (inviteCode != null) {
          _handleInAppInviteLink(inviteCode);
          return;
        }

        if (uri.scheme == 'io.supabase.nosus') {
          await handleOAuthCallback(uri);
        } else if (uri.scheme == 'foo.nosus.app' && uri.host == 'v') {
          final token = uri.pathSegments.firstOrNull;
          if (token != null && token.isNotEmpty) {
            _handleInAppShareView(token);
          }
        } else if (uri.scheme == 'https') {
          // Android App Links hand us every https link to app.nosus.foo —
          // see _routeIncomingWebLink for why this catch-all is mandatory.
          _routeIncomingWebLink(uri);
        }
      });

      // Handle initial link if app was closed
      try {
        final initialUri = await appLinks.getInitialLink();
        if (initialUri != null) {
          final inviteCode = extractInviteToken(initialUri);
          if (inviteCode != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleInAppInviteLink(inviteCode);
            });
          } else if (initialUri.scheme == 'io.supabase.nosus') {
            await handleOAuthCallback(initialUri);
          } else if (initialUri.scheme == 'foo.nosus.app' &&
              initialUri.host == 'v') {
            final token = initialUri.pathSegments.firstOrNull;
            if (token != null && token.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleInAppShareView(token);
              });
            }
          } else if (initialUri.scheme == 'https') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _routeIncomingWebLink(initialUri);
            });
          }
        }
      } catch (e) {
        debugLog('NO SUS: Error reading initial deep link: $e');
      }

      // Initialize security audit logging service
      AuditService.instance.init();
      // Screen protection does not need to hold the first useful frame.
      unawaited(ScreenshotGuard.instance.initialize());
      // 3. Device-integrity scan (root/Frida/Xposed) — fire-and-forget so a
      // 150ms socket probe never delays first paint; findings land in the
      // device_integrity_events ledger asynchronously.
      unawaited(DeviceIntegrityService.instance.runStartupChecks());

      // Initialize remote config and feature flags. Fire-and-forget — flags/
      // configs are mutated in place on the same instance handed to
      // remoteConfigServiceProvider below, and every consumer already falls
      // back to a default value until the fetch lands, so first paint never
      // needs to wait on this network round-trip.
      // In mock fallback mode there is no Supabase client at all — a null
      // client makes the service serve defaults (touching Supabase.instance
      // uninitalized would throw and kill boot before runApp).
      final remoteConfig = RemoteConfigService(
        SupabaseService.instance.isConfigured ? Supabase.instance.client : null,
      );
      if (SupabaseService.instance.isConfigured &&
          SupabaseService.instance.isReachable) {
        unawaited(remoteConfig.ensureInitialized());
      }

      runApp(
        ProviderScope(
          overrides: [
            remoteConfigServiceProvider.overrideWithValue(remoteConfig),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      // Catch all unhandled async errors (e.g. Supabase realtime WebSocket failures)
      // These are logged but do NOT crash the app — the mock fallback data remains active.
      debugLog('NO SUS: Caught unhandled async error: $error');
      if (CrashReportingConfig.isEnabled) {
        Sentry.captureException(error, stackTrace: stack);
      }
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize share intent listener early
    ref.watch(shareIntentProvider);
    final themeMode = ref.watch(themeModeProvider);

    final inviteToken = extractInviteToken(Uri.base);

    return MaterialApp(
      title: 'NO SUS',
      builder: (context, child) => ExperimentFrame(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      navigatorKey: ScreenshotGuard.instance.navigatorKey,
      theme: NoSusTheme.lightTheme,
      darkTheme: NoSusTheme.darkTheme,
      themeMode: themeMode,
      home: inviteToken != null
          ? GroupInviteLandingScreen(inviteCode: inviteToken)
          : const AuthGate(child: WorkspaceHome()),
      onGenerateRoute: (settings) {
        final route = settings.name ?? '';
        if (route == '/canary') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const CanaryHomeScreen(),
          );
        }
        if (route == '/monad' || route.startsWith('/monad/')) {
          final id = route.startsWith('/monad/')
              ? parseMonadDropId(route.substring('/monad/'.length)) : null;
          return MaterialPageRoute<void>(settings: settings,
            builder: (_) => MonadScreen(dropId: id));
        }
        // Web OAuth (Google/GitHub) redirects land on e.g. "/?code=..." — not
        // exactly "/", so Flutter treats it as a distinct route instead of
        // falling back to `home`. By the time this builds, Supabase has
        // already exchanged the code for a session (handled in main() before
        // runApp), so just show the same real entry point `home` would —
        // AuthGate reacts to the now-signed-in state normally.
        if (settings.name != null && settings.name!.contains('code=')) {
          return PageRouteBuilder(
            pageBuilder: (context, _, _) =>
                const AuthGate(child: WorkspaceHome()),
            transitionDuration: Duration.zero,
          );
        }
        return null;
      },
    );
  }
}

class WorkspaceHome extends ConsumerStatefulWidget {
  const WorkspaceHome({super.key});

  @override
  ConsumerState<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class ActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void changeTab(int index) {
    state = index;
  }
}

final activeTabProvider = NotifierProvider<ActiveTabNotifier, int>(() {
  return ActiveTabNotifier();
});

class _WorkspaceHomeState extends ConsumerState<WorkspaceHome> {
  int _currentTab = 0;
  String? _deskFileId;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentTab = ref.read(activeTabProvider);
    _pageController = PageController(initialPage: _currentTab);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shared = ref.read(shareIntentProvider);
      if (shared != null) {
        _showSaveToNoSusModal(shared);
      }

      _resumePendingIntent();
      _initPush();
    });
  }

  StreamSubscription? _pushTapSub;

  /// Brings up the push transport and wires notification taps to navigation.
  ///
  /// Deliberately does **not** request the notification permission: that is a
  /// contextual decision made after the user does something worth being
  /// notified about (see maybePrimeNotifications). Registering a token for an
  /// account that already granted permission on another install is separate
  /// from asking, and only the former happens here.
  ///
  /// With no Firebase project configured — the current state — initialize()
  /// returns false and everything below is a no-op. The in-app inbox still
  /// works; it reads Postgres directly.
  Future<void> _initPush() async {
    final available = await PushService.instance.initialize();
    if (!available || !mounted) return;

    if (await PushService.instance.hasPermission()) {
      await PushService.instance.registerCurrentDevice();
    }

    _pushTapSub = PushService.instance.onNotificationTap.listen((message) {
      if (!mounted) return;
      final navContext = ScreenshotGuard.instance.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      NotificationRouter.open(
        navContext,
        ref,
        message.data['deep_link'] as String?,
      );
    });

    // A tap that launched the app from terminated does not arrive on the
    // stream above — it has to be collected once, here.
    final launchMessage = await PushService.instance.initialMessage();
    if (launchMessage != null && mounted) {
      NotificationRouter.open(
        context,
        ref,
        launchMessage.data['deep_link'] as String?,
      );
    }
  }

  /// Replays whatever the user was trying to do before an auth wall stopped
  /// them.
  ///
  /// This is the landing point of the "preserve intent" contract: tap Join
  /// Community → sign up → arrive back at the join flow, rather than on Home
  /// having to find it again. Runs after the shell's first frame because two of
  /// the four intents are tab switches on this very widget.
  void _resumePendingIntent() {
    final intent = ref.read(pendingIntentProvider.notifier).take();
    if (intent == null || !mounted) return;

    AnalyticsService.instance.log(
      AnalyticsEvent.intentResumed,
      properties: {'kind': intent.kind.name},
    );

    switch (intent.kind) {
      case PendingIntentKind.joinGroup:
        final code = intent.payload;
        if (code == null || code.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupInviteLandingScreen(inviteCode: code),
          ),
        );
      case PendingIntentKind.openShare:
        final token = intent.payload;
        if (token == null || token.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InAppShareViewerScreen(token: token),
          ),
        );
      case PendingIntentKind.browseGroups:
        ref.read(activeTabProvider.notifier).changeTab(4);
      case PendingIntentKind.shareDocument:
        ref.read(activeTabProvider.notifier).changeTab(1);
    }
  }

  bool _isShareModalOpen = false;

  void _showSaveToNoSusModal(SharedContent content) {
    if (_isShareModalOpen) return;
    _isShareModalOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SaveToNoSusDialog(content: content),
    ).then((_) {
      _isShareModalOpen = false;
    });
  }

  @override
  void dispose() {
    _pushTapSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    ref.read(activeTabProvider.notifier).changeTab(index);
  }

  void _navigateToDesk(String fileId) {
    setState(() {
      _deskFileId = fileId;
    });
    ref.read(activeTabProvider.notifier).changeTab(2); // Jump to Study Desk
  }

  void _toggleTheme() {
    ref.read(themeModeProvider.notifier).toggle();
  }

  /// Runs [action] once the in-flight frame is done, skipping it if this state
  /// is gone by then. Provider listeners registered in [build] can fire during
  /// the build phase, where touching UI throws.
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // The wordmark is laid out against a fixed-width action row, so it has
        // to yield the leftover space rather than claim its natural width —
        // the tagline is wide enough to overflow narrow phones otherwise.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NO SUS',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'SILENT SECURITY WORKSPACE',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Minimalist Outlined Theme Selector Toggle
            Semantics(
              button: true,
              label: isDark ? 'Switch to light theme' : 'Switch to dark theme',
              child: GestureDetector(
                onTap: _toggleTheme,
                child: Container(
                  padding: const EdgeInsets.all(NoSusTheme.s12),
                  decoration: NoSusTheme.buttonDecoration(context, radius: 14),
                  child: Icon(
                    isDark
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_round_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: NoSusTheme.s12),
            // Notification inbox. Present regardless of push: the inbox reads
            // Postgres directly, so it is the reliable delivery channel and
            // push is the optimisation on top.
            _NotificationBell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationInboxScreen(),
                ),
              ),
            ),
            const SizedBox(width: NoSusTheme.s12),
            // Glowing Gradient Profile Avatar Button
            (() {
              final profileAsync = ref.watch(profileProvider);
              return profileAsync.maybeWhen(
                data: (profile) {
                  return Semantics(
                    button: true,
                    label: 'Your profile',
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: NoSusTheme.lBorder,
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
                            width: 1.0,
                          ),
                        ),
                        child: ClipOval(
                          child: ExcludeSemantics(
                            child: ProfileAvatar(profile: profile, size: 42),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                orElse: () => Semantics(
                  button: true,
                  label: 'Your profile',
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: NoSusTheme.buttonDecoration(
                        context,
                        radius: 21,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.onSurface,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              );
            })(),
          ],
        ),
      ],
    );
  }

  void _showNotificationBanner(ShareViewEvent event, String fileName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 6),
        // A dimmer blue in dark mode avoids an oversaturated highlight
        // against the near-black background; white text/icon keeps
        // sufficient contrast against either shade.
        backgroundColor: isDark ? Colors.blue.shade700 : Colors.blueAccent,
        content: Row(
          children: [
            const MascotView(
              character: MascotCharacter.nox,
              size: 20,
              fallback: Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${event.viewerEmail} opened "$fileName"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShareAnalyticsScreen(
                  linkId: event.linkId,
                  fileName: fileName,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // These three listeners all perform work that is illegal mid-build —
    // showing a snackbar or dialog, and jumping a PageController all call
    // setState/markNeedsBuild. A provider that changes while this tree is
    // building (a sign-out resetting the tab, for instance) delivered them
    // synchronously and tripped "setState() called during build", so each is
    // deferred to after the frame.
    ref.listen<ShareNotificationState>(shareNotificationProvider, (prev, next) {
      final event = next.latestEvent;
      if (event != null && next.fileName != null) {
        _afterFrame(() {
          _showNotificationBanner(event, next.fileName!);
          ref.read(shareNotificationProvider.notifier).dismiss();
        });
      }
    });

    ref.listen<SharedContent?>(shareIntentProvider, (previous, next) {
      if (next != null) {
        _afterFrame(() => _showSaveToNoSusModal(next));
      }
    });

    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next != previous) {
        _afterFrame(() {
          if (_pageController.hasClients) _pageController.jumpToPage(next);
        });
      }
    });

    _currentTab = ref.watch(activeTabProvider);

    ref.watch(focusSessionProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        // On desktop/web the phone-first layout would stretch edge to edge;
        // constraining the whole shell keeps content (and the floating nav,
        // which lives in the same Stack) in a centered readable column.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Stack(
              children: [
                // Main Content Area with thin border framing
                Padding(
                  padding: EdgeInsets.only(
                    left: NoSusTheme.s24,
                    right: NoSusTheme.s24,
                    top: NoSusTheme.s16,
                    // Space for floating bottom nav. The compact phone nav
                    // uses icons only, so it needs less reserved height.
                    bottom: FloatingNav.contentClearance(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Bar (Calm Monochrome UI Style)
                      _buildHeader(context, isDark),
                      const SizedBox(height: NoSusTheme.s24),

                      // Animated Screen Content — using PageView to preserve states properly
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics:
                              const NeverScrollableScrollPhysics(), // Prevent swipe
                          children: [
                            const WorkspaceTab(),
                            VaultTab(onRevealRequested: _navigateToDesk),
                            StudyDeskTab(initialFileId: _deskFileId),
                            const AuditTab(),
                            const GroupsScreen(key: ValueKey('groups_tab')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating bottom navigation
                FloatingNav(currentIndex: _currentTab, onTap: _onTabTapped),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header bell with an unread badge.
///
/// The count is announced in the semantics label, not conveyed by the dot
/// alone — a red circle is invisible to a screen reader and to anyone who
/// cannot distinguish it against the header.
class _NotificationBell extends ConsumerWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Semantics(
      button: true,
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(NoSusTheme.s12),
          decoration: NoSusTheme.buttonDecoration(context, radius: 14),
          child: ExcludeSemantics(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  unread > 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
                if (unread > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _handleInAppShareView(String token) {
  final context = ScreenshotGuard.instance.navigatorKey.currentContext;
  if (context != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InAppShareViewerScreen(token: token),
      ),
    );
  }
}

void _handleInAppInviteLink(String inviteCode) {
  final context = ScreenshotGuard.instance.navigatorKey.currentContext;
  if (context != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInviteLandingScreen(inviteCode: inviteCode),
      ),
    );
  }
}

/// Routes an incoming `https://app.nosus.foo/...` link to the viewer it names.
/// Returns true if the link was recognised and handled.
///
/// **Why every shape has to be handled here.** The Android App Links filter for
/// `app.nosus.foo` is necessarily host-wide: an intent filter cannot match on a
/// URL fragment, and every link this app mints is fragment-shaped at path `/`
/// (`/#/burn/<id>?k=…`, `/#/burnfile/<id>`, `/#/burnfiles/<ids>`,
/// `/#/redeem/<token>`, `/?cb=…#/v/…`, `/#/join/<code>`). So once the app is
/// installed it intercepts *all* of them.
/// Anything not routed here is silently swallowed — the recipient lands on the
/// home screen and a single-use link looks broken, with no browser fallback,
/// because the system already chose the app over the web page.
///
/// On web these same shapes are handled off `Uri.base` in [main] before the
/// normal app boots, each in its own standalone `runApp`. Native cannot do that
/// (the app may already be running), so they become pushed routes instead —
/// same screens, same anonymous fetch path, no session required.
///
/// Order mirrors the web branches deliberately: single-file burn is checked
/// before multi-file so an old `burnfile/<uuid>` link is never re-parsed by the
/// plural matcher.
bool _routeIncomingWebLink(Uri uri) {
  final context = ScreenshotGuard.instance.navigatorKey.currentContext;
  if (context == null) return false;

  final shareToken = extractShareToken(uri);
  if (shareToken != null) {
    _handleInAppShareView(shareToken);
    return true;
  }

  final canary = extractCanaryToken(uri);
  if (canary != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CanaryReaderScreen(
          noteId: canary.noteId,
          keyHex: canary.keyHex,
        ),
      ),
    );
    return true;
  }

  final redemptionToken = extractRedemptionToken(uri);
  if (redemptionToken != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RedeemCodeScreen(redeemToken: redemptionToken),
      ),
    );
    return true;
  }

  final burnNote = extractBurnNoteToken(uri);
  if (burnNote != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BurnNoteViewerScreen(
          noteId: burnNote.id,
          keyHex: burnNote.keyHex,
          ivHex: burnNote.ivHex,
        ),
      ),
    );
    return true;
  }

  final burnFile = extractBurnFileToken(uri);
  if (burnFile != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BurnFileViewerScreen(
          files: [
            (id: burnFile.id, keyHex: burnFile.keyHex, ivHex: burnFile.ivHex),
          ],
        ),
      ),
    );
    return true;
  }

  final burnFiles = extractBurnFilesToken(uri);
  if (burnFiles != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BurnFileViewerScreen(
          files: burnFiles
              .map((t) => (id: t.id, keyHex: t.keyHex, ivHex: t.ivHex))
              .toList(),
        ),
      ),
    );
    return true;
  }

  return false;
}
