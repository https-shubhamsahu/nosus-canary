import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../data/remote_config_service.dart';


/// Provider for the [RemoteConfigService] singleton.
///
/// main.dart overrides this with the boot-time instance; this default body
/// only runs in tests or entrypoints without the override, so it must stay
/// safe when Supabase was never initialized (mock fallback mode).
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  final service = RemoteConfigService(
    SupabaseBootstrap.isConfigured ? Supabase.instance.client : null,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// FutureProvider to handle initialization of the remote config.
final configInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(remoteConfigServiceProvider);
  await service.ensureInitialized();
});

/// Family provider to check if a specific [flagKey] is enabled for the current user.
/// It watches the active authenticated user's ID to perform targeting checks.
final featureFlagProvider = Provider.family<bool, String>((ref, flagKey) {
  final user = ref.watch(authStateProvider).value;
  final service = ref.watch(remoteConfigServiceProvider);
  
  if (user == null) {
    return false;
  }
  
  return service.isFeatureEnabled(flagKey, user.id);
});

/// Family provider to get a remote configuration value.
final remoteConfigValueProvider = Provider.family<dynamic, _ConfigParam>((ref, param) {
  final service = ref.watch(remoteConfigServiceProvider);
  return service.getConfigValue(param.key, param.defaultValue);
});

/// FutureProvider to fetch the user role dynamically from user_roles table.
final userRoleProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return 'user';
  
  try {
    final response = await Supabase.instance.client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    return response?['role'] as String? ?? 'user';
  } catch (e) {
    debugLog('Config: Failed to fetch user role: $e');
    return 'user';
  }
});

/// Helper class for defining remote config parameters with defaults.
class _ConfigParam {
  final String key;
  final dynamic defaultValue;

  const _ConfigParam(this.key, this.defaultValue);
}

/// Predefined parameters for the SecureSend application configs.
class SecureSendConfigs {
  SecureSendConfigs._();

  static const maxExpiryDays = _ConfigParam(
    'securesend_max_expiry_days',
    30,
  );

  static const maxViewsDefault = _ConfigParam(
    'securesend_max_views_default',
    10,
  );

  static const minSupportedVersion = _ConfigParam(
    'min_supported_client_version',
    '1.0.0',
  );

  static const appDownloadUrl = _ConfigParam(
    'app_download_url',
    // GitHub Releases page — the play-store workflow attaches an APK to each
    // tagged release. (The old nosus.foo/app-release.apk was never actually
    // hosted; it 404'd in production.)
    'https://github.com/https-shubhamsahu/NON_SUS/releases/latest',
  );

  static const appLatestVersion = _ConfigParam(
    'app_latest_version',
    // Empty default = "latest version unknown" — the update banner stays
    // hidden rather than guessing. The row is bumped as part of each release
    // (see CLAUDE.md, CI section).
    '',
  );
}


