import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class FocusService {
  static final FocusService instance = FocusService._internal();
  FocusService._internal();

  bool _isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<Map<DateTime, int>> fetchFocusLogs(String userId) async {
    final Map<DateTime, int> localLogs = {};
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Load local logs for the last 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final key = 'nosus_focus_log_${userId}_$dateStr';
      final minutes = prefs.getInt(key) ?? 0;
      if (minutes > 0) {
        localLogs[DateTime(date.year, date.month, date.day)] = minutes;
      }
    }

    // 2. If online and valid UUID, sync with Supabase
    if (_isValidUuid(userId) && SupabaseService.instance.isConfigured && SupabaseService.instance.isReachable) {
      try {
        final serverLogs = await SupabaseService.instance.fetchFocusLogs(userId);
        
        // Merge server logs with local logs
        // Rule: take the maximum of local vs server, and update local storage with server values.
        for (final entry in serverLogs.entries) {
          final dateStr = entry.key.toIso8601String().substring(0, 10);
          final key = 'nosus_focus_log_${userId}_$dateStr';
          final localMinutes = prefs.getInt(key) ?? 0;
          if (entry.value > localMinutes) {
            await prefs.setInt(key, entry.value);
            localLogs[entry.key] = entry.value;
          } else if (localMinutes > entry.value) {
            // Server has fewer minutes (local offline additions), we should update Supabase!
            final diff = localMinutes - entry.value;
            await SupabaseService.instance.incrementFocusMinutes(userId, diff);
          }
        }
        
        // Re-read local logs to ensure everything is perfectly aligned
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          final dateStr = date.toIso8601String().substring(0, 10);
          final key = 'nosus_focus_log_${userId}_$dateStr';
          final minutes = prefs.getInt(key) ?? 0;
          if (minutes > 0) {
            localLogs[DateTime(date.year, date.month, date.day)] = minutes;
          }
        }
      } catch (e) {
        // Safe to ignore, we fallback to local logs
      }
    }

    return localLogs;
  }

  Future<void> incrementFocusMinutes(String userId, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
    final key = 'nosus_focus_log_${userId}_$todayStr';
    final currentMinutes = prefs.getInt(key) ?? 0;
    
    // Save locally first
    await prefs.setInt(key, currentMinutes + minutes);

    // If online & UUID is valid, sync with Supabase
    if (_isValidUuid(userId) && SupabaseService.instance.isConfigured && SupabaseService.instance.isReachable) {
      await SupabaseService.instance.incrementFocusMinutes(userId, minutes);
    }
  }
}
