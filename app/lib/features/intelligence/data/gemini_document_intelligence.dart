import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';
import '../../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/document_intelligence.dart';

/// Gemini adapter. The API key stays on the server — this client only
/// calls the `document-intelligence` Edge Function with the user JWT.
class GeminiDocumentIntelligence implements DocumentIntelligence {
  GeminiDocumentIntelligence({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  @override
  bool get isAvailable =>
      SupabaseCredentials.url.isNotEmpty && SupabaseCredentials.anonKey.isNotEmpty;

  @override
  String get providerLabel => 'Gemini';

  @override
  Future<DocumentInsight> inspect({
    required String title,
    required String mimeType,
    String? plainText,
  }) async {
    final uri = Uri.parse(
      '${SupabaseCredentials.url}/functions/v1/document-intelligence',
    );
    final session = SupabaseService.instance.isReachable
        ? Supabase.instance.client.auth.currentSession
        : null;
    final bearer = session?.accessToken ?? SupabaseCredentials.anonKey;
    final res = await _http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseCredentials.anonKey,
        'Authorization': 'Bearer $bearer',
      },
      body: jsonEncode({
        'title': title,
        'mime_type': mimeType,
        'text': plainText,
      }),
    );
    if (res.statusCode != 200) {
      throw StateError('Insight request failed (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DocumentInsight(
      summary: data['summary'] as String? ?? '',
      classification: data['classification'] as String? ?? 'Document',
      highlights: List<String>.from(data['highlights'] as List? ?? const []),
    );
  }
}
