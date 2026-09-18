import '../domain/document_intelligence.dart';

/// Tiny on-device classifier. No model load, no network, no startup cost.
///
/// Good enough for a local-AI competition lane without dragging a LLM into
/// the default product. Gemini is a separate adapter.
class LocalDocumentIntelligence implements DocumentIntelligence {
  const LocalDocumentIntelligence();

  @override
  bool get isAvailable => true;

  @override
  String get providerLabel => 'On-device';

  @override
  Future<DocumentInsight> inspect({
    required String title,
    required String mimeType,
    String? plainText,
  }) async {
    final classification = _classify(title, mimeType, plainText);
    final text = (plainText ?? '').trim();
    final summary = text.isEmpty
        ? 'No extractable text. Classified as $classification from the file name and type.'
        : _firstSentences(text, 2);
    return DocumentInsight(
      summary: summary,
      classification: classification,
      highlights: _keywords(text),
    );
  }

  static String _classify(String title, String mimeType, String? text) {
    final hay = '${title.toLowerCase()} ${mimeType.toLowerCase()} ${(text ?? '').toLowerCase()}';
    if (hay.contains('nda') || hay.contains('non-disclosure')) return 'Agreement';
    if (hay.contains('invoice') || hay.contains('receipt')) return 'Financial';
    if (hay.contains('resume') || hay.contains('cv')) return 'Identity';
    if (mimeType.contains('pdf')) return 'Document';
    if (mimeType.startsWith('image/')) return 'Image';
    return 'File';
  }

  static String _firstSentences(String text, int count) {
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    return parts.take(count).join(' ').trim();
  }

  static List<String> _keywords(String text) {
    if (text.isEmpty) return const [];
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 5)
        .toList();
    final seen = <String>{};
    final out = <String>[];
    for (final w in words) {
      if (seen.add(w)) out.add(w);
      if (out.length >= 5) break;
    }
    return out;
  }
}
