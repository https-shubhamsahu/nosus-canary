/// Play Integrity API feature flag.
///
/// Off by default. Even once [enabled] is flipped on via
/// `--dart-define=APP_INTEGRITY_ENABLED=true`, requesting a real token still
/// requires:
///   1. A Google Cloud project linked to this app in Play Console (App
///      integrity → Play Integrity API), with the Play Integrity API enabled.
///   2. That project's number filled into `cloudProjectNumber` in
///      android/app/src/main/kotlin/foo/nosus/app/security/PlayIntegrityManager.kt
///      (currently 0, which fails fast rather than silently misbehaving).
///   3. The app installed via Play (or Play's internal testing track) —
///      Play Integrity tokens can't be minted for a sideloaded debug build.
///   4. supabase/functions/verify-play-integrity deployed and able to call
///      Google's decodeIntegrityToken endpoint with a service account that
///      has Play Integrity API access (GOOGLE_PLAY_SERVICE_ACCOUNT_JSON may
///      or may not already have this scope — verify before relying on it).
///
/// None of this has been exercised against a real device/token in this
/// environment — the plumbing is written and internally consistent, not
/// verified end-to-end. Treat as scaffolding until someone completes the
/// four steps above and tests on a real device.
class AppIntegrityConfig {
  AppIntegrityConfig._();

  static const bool enabled =
      bool.fromEnvironment('APP_INTEGRITY_ENABLED', defaultValue: false);
}
