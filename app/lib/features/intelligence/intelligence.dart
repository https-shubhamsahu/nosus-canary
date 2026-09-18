import '../../config/intelligence_config.dart';
import 'data/disabled_document_intelligence.dart';
import 'data/gemini_document_intelligence.dart';
import 'data/local_document_intelligence.dart';
import 'domain/document_intelligence.dart';

export 'domain/document_intelligence.dart';

/// Single factory for the optional intelligence layer.
DocumentIntelligence createDocumentIntelligence() {
  if (IntelligenceConfig.useGemini) return GeminiDocumentIntelligence();
  if (IntelligenceConfig.useLocal) return const LocalDocumentIntelligence();
  return const DisabledDocumentIntelligence();
}
