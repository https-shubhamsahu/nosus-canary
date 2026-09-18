import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/intelligence_config.dart';
import '../data/disabled_document_intelligence.dart';
import '../data/gemini_document_intelligence.dart';
import '../data/local_document_intelligence.dart';
import '../domain/document_intelligence.dart';

final documentIntelligenceProvider = Provider<DocumentIntelligence>((ref) {
  switch (IntelligenceConfig.provider) {
    case 'gemini':
      return GeminiDocumentIntelligence();
    case 'local':
      return const LocalDocumentIntelligence();
    case 'disabled':
    default:
      return const DisabledDocumentIntelligence();
  }
});
