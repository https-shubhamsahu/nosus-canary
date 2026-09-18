import 'dart:typed_data';

/// Session-scoped LRU for downloaded document bytes.
///
/// Re-opening a document currently re-downloads it every time. This keeps the
/// most recently viewed files in memory so a re-open is instant. Deliberately
/// memory-only: nothing secure ever touches disk, it vanishes with the
/// process, and there's no I/O that could jank the UI. Bounded by both total
/// bytes and entry count so it can never balloon.
class DocumentCache {
  DocumentCache._();
  static final DocumentCache instance = DocumentCache._();

  static const int _maxTotalBytes = 40 * 1024 * 1024; // 40 MB
  static const int _maxEntries = 12;

  // LinkedHashMap iteration order = insertion order; re-inserting on access
  // makes the first key the least recently used.
  final _entries = <String, Uint8List>{};
  int _totalBytes = 0;

  Uint8List? get(String fileId) {
    final bytes = _entries.remove(fileId);
    if (bytes == null) return null;
    _entries[fileId] = bytes; // refresh recency
    return bytes;
  }

  void put(String fileId, Uint8List bytes) {
    // A single file larger than the whole budget just isn't cached.
    if (bytes.length > _maxTotalBytes) return;
    final existing = _entries.remove(fileId);
    if (existing != null) _totalBytes -= existing.length;

    _entries[fileId] = bytes;
    _totalBytes += bytes.length;

    while (_totalBytes > _maxTotalBytes || _entries.length > _maxEntries) {
      final oldestKey = _entries.keys.first;
      _totalBytes -= _entries.remove(oldestKey)!.length;
    }
  }

  /// Called when a file is deleted or replaced so stale bytes can't be shown.
  void evict(String fileId) {
    final removed = _entries.remove(fileId);
    if (removed != null) _totalBytes -= removed.length;
  }

  void clear() {
    _entries.clear();
    _totalBytes = 0;
  }
}
