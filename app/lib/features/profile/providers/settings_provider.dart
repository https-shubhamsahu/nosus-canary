import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TouchToRevealNotifier extends Notifier<bool> {
  static const _key = 'nosus_touch_to_reveal';

  @override
  bool build() {
    _loadState();
    return true; // Default to true
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_key);
    if (val != null) {
      state = val;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final touchToRevealProvider = NotifierProvider<TouchToRevealNotifier, bool>(
  TouchToRevealNotifier.new,
);

class WatermarkVisibilityNotifier extends Notifier<bool> {
  static const _key = 'nosus_watermark_visibility';

  @override
  bool build() {
    _loadState();
    return true; // Default to true
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_key);
    if (val != null) {
      state = val;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final watermarkVisibilityProvider = NotifierProvider<WatermarkVisibilityNotifier, bool>(
  WatermarkVisibilityNotifier.new,
);
