import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/debug_logger.dart';
import '../domain/feature_flag.dart';

/// Service responsible for managing dynamic feature flags and remote configs.
/// It caches the values locally and keeps them updated in real-time.
///
/// A null [SupabaseClient] means mock fallback mode (no backend): every
/// lookup returns its caller-provided default and [initialize] is a no-op —
/// constructing this must never touch `Supabase.instance`, which throws when
/// the SDK was never initialized.
class RemoteConfigService {
  final SupabaseClient? _supabase;
  final Map<String, FeatureFlag> _flags = {};
  final Map<String, dynamic> _configs = {};
  RealtimeChannel? _flagsChannel;
  RealtimeChannel? _configsChannel;
  Future<void>? _initFuture;

  RemoteConfigService(this._supabase);

  /// Memoized [initialize] — safe to await from multiple call sites without
  /// re-fetching or double-subscribing the realtime channels.
  Future<void> ensureInitialized() => _initFuture ??= initialize();

  /// Loads all flags and configurations from the database and starts real-time subscriptions.
  Future<void> initialize() async {
    final supabase = _supabase;
    if (supabase == null) {
      debugLog('Config: No backend (mock fallback mode). Using defaults.');
      return;
    }
    try {
      debugLog('Config: Initializing remote configuration...');
      
      // Fetch initial feature flags
      final flagRows = await supabase.from('feature_flags').select();
      _flags.clear();
      for (final row in flagRows) {
        final flag = FeatureFlag.fromJson(row);
        _flags[flag.key] = flag;
      }
      debugLog('Config: Loaded ${_flags.length} feature flags.');

      // Fetch initial remote configurations
      final configRows = await supabase.from('remote_configs').select();
      _configs.clear();
      for (final row in configRows) {
        _configs[row['config_key'] as String] = row['config_value'];
      }
      debugLog('Config: Loaded ${_configs.length} remote configurations.');

      // Start real-time sync
      _subscribeToRealtime();
    } catch (e) {
      debugLog('Config: Initialization failed (offline or unauthenticated). Using defaults. Error: $e');
    }
  }

  /// Checks if a feature flag is enabled for the current user.
  /// Falls back to [defaultValue] if the flag does not exist or fetch failed.
  bool isFeatureEnabled(String flagKey, String userId, {bool defaultValue = false}) {
    final flag = _flags[flagKey];
    if (flag == null) {
      return defaultValue;
    }
    return flag.isEnabledFor(userId);
  }

  /// Gets a remote configuration value cast to [T].
  /// Falls back to [defaultValue] if the configuration key is missing.
  T getConfigValue<T>(String key, T defaultValue) {
    final value = _configs[key];
    if (value == null) {
      return defaultValue;
    }
    try {
      if (T == int && value is num) {
        return value.toInt() as T;
      }
      if (T == double && value is num) {
        return value.toDouble() as T;
      }
      return value as T;
    } catch (e) {
      debugLog('Config: Failed to cast config value for key "$key" to $T: $e');
      return defaultValue;
    }
  }

  /// Subscribes to real-time database modifications to support instant remote toggles.
  void _subscribeToRealtime() {
    final supabase = _supabase;
    if (supabase == null) return;
    try {
      _flagsChannel = supabase
          .channel('public:feature_flags')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'feature_flags',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              
              if (payload.eventType == PostgresChangeEvent.delete && oldRecord.isNotEmpty) {
                final key = oldRecord['flag_key'] as String?;
                if (key != null) {
                  _flags.remove(key);
                  debugLog('Config: Feature flag "$key" deleted via remote.');
                }
              } else if (newRecord.isNotEmpty) {
                final flag = FeatureFlag.fromJson(newRecord);
                _flags[flag.key] = flag;
                debugLog('Config: Feature flag "${flag.key}" updated via remote. Active: ${flag.isActive}, Rollout: ${flag.rolloutPercentage}%');
              }
            },
          )
          .subscribe();

      _configsChannel = supabase
          .channel('public:remote_configs')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'remote_configs',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;

              if (payload.eventType == PostgresChangeEvent.delete && oldRecord.isNotEmpty) {
                final key = oldRecord['config_key'] as String?;
                if (key != null) {
                  _configs.remove(key);
                  debugLog('Config: Remote config "$key" deleted via remote.');
                }
              } else if (newRecord.isNotEmpty) {
                final key = newRecord['config_key'] as String;
                final value = newRecord['config_value'];
                _configs[key] = value;
                debugLog('Config: Remote config "$key" updated via remote to: $value');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugLog('Config: Realtime subscription failed: $e');
    }
  }

  /// Closes real-time channels when disposing.
  void dispose() {
    if (_flagsChannel != null) {
      _supabase?.removeChannel(_flagsChannel!);
    }
    if (_configsChannel != null) {
      _supabase?.removeChannel(_configsChannel!);
    }
  }
}
