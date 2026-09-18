import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/canary_models.dart';

/// Local-only storage for Canary (SharedPreferences = localStorage on web).
class CanaryStore {
  CanaryStore(this._prefs);

  final SharedPreferences _prefs;

  static const _notesKey = 'nosus_canary_notes_v1';
  static const _deviceKey = 'nosus_canary_device_id_v1';
  static const _readerNameKey = 'nosus_canary_reader_name_v1';

  /// Newest first. Entries that cannot be read are skipped, never thrown.
  List<CanaryOwnerRecord> loadNotes() {
    final raw = _prefs.getString(_notesKey);
    if (raw == null) return [];
    final List<dynamic> list;
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
    final records = <CanaryOwnerRecord>[];
    for (final entry in list) {
      try {
        records.add(
          CanaryOwnerRecord.fromJson((entry as Map).cast<String, dynamic>()),
        );
      } catch (_) {
        // Skip a damaged entry rather than losing every note.
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  CanaryOwnerRecord? findNote(String noteId) {
    for (final r in loadNotes()) {
      if (r.noteId == noteId) return r;
    }
    return null;
  }

  Future<void> saveNote(CanaryOwnerRecord record) async {
    final others = loadNotes().where((r) => r.noteId != record.noteId);
    final all = [record, ...others];
    await _prefs.setString(
      _notesKey,
      jsonEncode([for (final r in all) r.toJson()]),
    );
  }

  Future<void> deleteNote(String noteId) async {
    final remaining = loadNotes().where((r) => r.noteId != noteId).toList();
    await _prefs.setString(
      _notesKey,
      jsonEncode([for (final r in remaining) r.toJson()]),
    );
  }

  /// Random id for this browser/app install. Lets a reader reopen the same
  /// copy instead of consuming a new one.
  Future<String> deviceId() async {
    final existing = _prefs.getString(_deviceKey);
    if (existing != null && existing.length == 36) return existing;
    final created = const Uuid().v4();
    await _prefs.setString(_deviceKey, created);
    return created;
  }

  String? lastReaderName() => _prefs.getString(_readerNameKey);

  Future<void> rememberReaderName(String name) =>
      _prefs.setString(_readerNameKey, name);
}
