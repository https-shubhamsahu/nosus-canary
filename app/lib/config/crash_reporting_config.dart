/// Crash reporting configuration (Sentry).
///
/// Off by default — [sentryDsn] is empty until explicitly provided via
/// `--dart-define=SENTRY_DSN=...` (or a `.env` picked up by
/// `--dart-define-from-file`) and is disabled unless explicitly configured.
/// To turn this on:
///   1. Create a free project at sentry.io (Flutter platform).
///   2. Copy its DSN.
///   3. Add `SENTRY_DSN=https://...` to your `.env` / CI secret and pass it
///      through `--dart-define-from-file`.
///   4. Update `store_listing/data_safety_answers.md` — enabling this adds a
///      new third-party data flow (crash/error metadata to Sentry) that the
///      Play Console Data Safety form does not currently disclose.
///
/// This product's whole premise is zero-knowledge/no-tracking (see
/// PROJECT_CONSTITUTION.md), so the wiring in main.dart deliberately sets
/// `sendDefaultPii = false` and keeps tracing off by default — this is
/// crash/error visibility, not analytics.
class CrashReportingConfig {
  CrashReportingConfig._();

  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  static bool get isEnabled => sentryDsn.isNotEmpty;

  /// Performance tracing is separate from error capture and stays off even
  /// when error capture is enabled — it's a distinct data flow (full
  /// request/navigation traces) this product doesn't opt into silently.
  /// (No dart-define for this one — there's no `double.fromEnvironment` in
  /// Dart, and tracing isn't something to flip on casually for this
  /// product anyway; change this constant directly if it's ever needed.)
  static const double tracesSampleRate = 0.0;
}
