/// Optional document-intelligence layer. Completely independent of sharing,
/// auth, and viewing.
///
/// The core product works with every flag false. Providers are selected at
/// compile time so a Gemini competition build does not ship a local model,
/// and a local-AI build does not need a cloud key.
///
///   --dart-define=INTELLIGENCE_PROVIDER=gemini
///   --dart-define=INTELLIGENCE_PROVIDER=local
///
/// Credentials never live in the client. Gemini goes through a server
/// function that holds `GEMINI_API_KEY`. Local runs on-device with no
/// network.
class IntelligenceConfig {
  IntelligenceConfig._();

  static const String provider = String.fromEnvironment(
    'INTELLIGENCE_PROVIDER',
    defaultValue: 'disabled',
  );

  static bool get isDisabled => provider == 'disabled' || provider.isEmpty;
  static bool get isEnabled => !isDisabled;
  static bool get useGemini => provider == 'gemini';
  static bool get useLocal => provider == 'local';
}
