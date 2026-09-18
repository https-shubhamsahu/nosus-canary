import 'package:flutter/foundation.dart';

/// Measure (measure.sh) monitoring configuration.
///
/// Off by default, exactly like [CrashReportingConfig] — both values are empty
/// until supplied via `--dart-define=MEASURE_API_KEY=...` /
/// `--dart-define=MEASURE_API_URL=...` (or a `.env` picked up by
/// `--dart-define-from-file`, which is how CI does it). With either one blank
/// the SDK is never initialised and never started, so an unconfigured build
/// carries the dependency but performs no collection and makes no network
/// calls.
///
/// **Android only.** `measure_flutter` registers plugin implementations for
/// `android` and `ios` only. It is conditionally imported by
/// `services/measure_reporting.dart`, so its JavaScript-incompatible package
/// code is excluded from the web program rather than merely skipped at runtime.
/// iOS is excluded too: that target has never shipped (still on Flutter's
/// `com.example.*` template ids, see AGENTS.md §5) and Measure's iOS setup
/// needs a `pod install` + `AppDelegate` change that does not exist here.
///
/// **The same two values are also read by Gradle**, out of the repo-root
/// `.env`, and injected into `AndroidManifest.xml` as the
/// `sh.measure.android.API_KEY` / `API_URL` meta-data the native SDK reads —
/// see `android/app/build.gradle.kts`. That is not duplication for its own
/// sake: the native SDK initialises in `Application.onCreate`, long before Dart
/// exists, so it cannot be told anything by a `--dart-define`. Keeping both
/// sides fed from one `.env` is what stops the Dart gate and the native gate
/// from disagreeing. If you set one without the other, the half that is
/// configured runs and the half that is not stays dark.
///
/// ## Before enabling this, know what it collects
///
/// Measure is session monitoring, not just crash capture, and two of its
/// behaviours are actively dangerous for *this* product:
///
/// 1. **Screenshot-on-crash cannot be turned off from app code.** It lives in
///    the SDK's server-driven `DynamicConfig` (`crash_take_screenshot`,
///    defaults to `true`), fetched from the Measure backend — neither the Dart
///    nor the Android `MeasureConfig` exposes it. It must be disabled in the
///    Measure dashboard. Until it is, a crash inside `BurnNoteViewerScreen`,
///    `BurnFileViewerScreen` or `SpyglassViewer` can upload decrypted content.
///    `MainActivity` sets `FLAG_SECURE` window-wide, which blanks the `PixelCopy`
///    capture path the SDK uses on API 26+, but it falls back to the Canvas API
///    on older devices and `FLAG_SECURE` does not block that.
/// 2. **Gesture tracking records widget labels.** `ClickData` carries `label`
///    and `semanticLabel`, which in this app are note titles, group names and
///    filenames. This is why `main.dart` deliberately does **not** wrap the app
///    in `MeasureWidget` and does not install `MsrNavigatorObserver` — without
///    that wrapper the SDK captures crashes and app-health metrics but no
///    interaction timeline. Adding either re-opens this; don't, without
///    re-reading `store_listing/data_safety_answers.md`.
///
/// Turning this on is a Play Data Safety change (a new third-party data flow),
/// same as `SENTRY_DSN` — see `store_listing/data_safety_answers.md`.
class MeasureReportingConfig {
  MeasureReportingConfig._();

  static const String apiKey =
      String.fromEnvironment('MEASURE_API_KEY', defaultValue: '');

  static const String apiUrl =
      String.fromEnvironment('MEASURE_API_URL', defaultValue: '');

  /// Both halves of the credential must be present — a key without a URL (or
  /// vice versa) is a misconfiguration, not a partial enablement.
  static bool get isConfigured => apiKey.isNotEmpty && apiUrl.isNotEmpty;

  /// `kIsWeb` is checked *first* and separately: [defaultTargetPlatform] reports
  /// `TargetPlatform.android` for Chrome on an Android phone, so a web-only
  /// check via the platform enum alone would let the web build through.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isEnabled => isConfigured && isSupportedPlatform;
}
