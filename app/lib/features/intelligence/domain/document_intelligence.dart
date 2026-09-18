/// Provider-agnostic document insights. UI talks only to this interface.
abstract class DocumentIntelligence {
  bool get isAvailable;

  /// Short label for settings/debug ("Off", "Gemini", "On-device").
  String get providerLabel;

  Future<DocumentInsight> inspect({
    required String title,
    required String mimeType,
    String? plainText,
  });
}

class DocumentInsight {
  final String summary;
  final String classification;
  final List<String> highlights;

  const DocumentInsight({
    required this.summary,
    required this.classification,
    this.highlights = const [],
  });
}
