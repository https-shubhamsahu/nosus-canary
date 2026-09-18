/// Feature flags and endpoint names for the optional multi-cloud storage router.
///
/// Existing Supabase Storage remains the default. When STORAGE_MULTICLOUD=true,
/// uploads/downloads/deletes are routed through the `storage-router` Edge
/// Function, which owns S3-compatible provider credentials and provider choice.
class StorageRouterConfig {
  StorageRouterConfig._();

  static const bool enableMultiCloudStorage = bool.fromEnvironment(
    'STORAGE_MULTICLOUD',
    defaultValue: false,
  );

  static const String edgeFunctionName = 'storage-router';
}
