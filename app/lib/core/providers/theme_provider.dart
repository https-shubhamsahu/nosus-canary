import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider exposing the pre-initialized SharedPreferences instance.
/// Overridden in the root ProviderScope at app boot.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been pre-initialized');
});

/// Global theme mode provider — replaces the `setState`-based `_themeMode` in MyApp.
///
/// Reads SharedPreferences synchronously from the provider to prevent startup flicker.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'nosus_theme_mode';

  @override
  ThemeMode build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final val = prefs.getString(_key);
      return val == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark; // Fallback default
    }
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_key, newMode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
  
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
