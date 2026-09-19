/// True only for the standalone NO SUS Canary web build
/// (flutter build web ... --dart-define=NOSUS_CANARY_ONLY=true).
/// The full NO SUS app (APK, main web app) never sets it.
const bool kCanaryOnly = bool.fromEnvironment('NOSUS_CANARY_ONLY');

/// Optional deployed contract address to show on the Canary landing page.
const String kCanaryContract = String.fromEnvironment(
  'CANARY_CONTRACT',
  defaultValue: '0xb1a1858866122c84cf97861ca815fb070e010e68',
);

/// Optional repo URL for the open-source link in the hero/footer.
const String kCanaryRepoUrl = String.fromEnvironment(
  'CANARY_REPO_URL',
  defaultValue: 'https://github.com/https-shubhamsahu/nosus-monad',
);
