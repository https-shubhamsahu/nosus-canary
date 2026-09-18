import '../domain/document_intelligence.dart';

class DisabledDocumentIntelligence implements DocumentIntelligence {
  const DisabledDocumentIntelligence();

  @override
  bool get isAvailable => false;

  @override
  String get providerLabel => 'Off';

  @override
  Future<DocumentInsight> inspect({
    required String title,
    required String mimeType,
    String? plainText,
  }) async {
    throw StateError('Document intelligence is disabled in this build.');
  }
}
