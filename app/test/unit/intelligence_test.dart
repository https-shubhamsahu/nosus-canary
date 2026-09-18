import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/intelligence/data/disabled_document_intelligence.dart';
import 'package:no_sus/features/intelligence/data/local_document_intelligence.dart';

void main() {
  test('disabled provider is not available', () {
    expect(const DisabledDocumentIntelligence().isAvailable, isFalse);
  });

  test('local provider classifies without a model', () async {
    final intel = const LocalDocumentIntelligence();
    final insight = await intel.inspect(
      title: 'NDA-acme.pdf',
      mimeType: 'application/pdf',
      plainText: 'This non-disclosure agreement binds both parties. Confidential terms follow.',
    );
    expect(insight.classification, 'Agreement');
    expect(insight.summary, isNotEmpty);
  });
}
