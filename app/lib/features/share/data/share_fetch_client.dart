import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';
import '../domain/entities/share_link.dart';

/// Calls the public `share-fetch` Edge Function directly over HTTPS — no
/// Supabase client, no session, no JWT. This is intentional: a share-link
/// recipient may have no account at all, so this client can never depend on
/// being signed in. The token itself is the credential (see
/// supabase/functions/share-fetch/index.ts).
class ShareFetchClient {
  ShareFetchClient._();
  static final ShareFetchClient instance = ShareFetchClient._();

  static final Uri _endpoint =
      Uri.parse('${SupabaseCredentials.url}/functions/v1/share-fetch');

  Future<ShareFetchResult> fetch({
    required String token,
    required String viewerEmail,
    String? deviceType,
  }) async {
    final res = await http.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        'apikey': SupabaseCredentials.anonKey,
      },
      body: jsonEncode({
        'token': token,
        'viewer_email': viewerEmail,
        'device_type': deviceType ?? 'web',
      }),
    );

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(decoded['error'] as String? ?? 'This link could not be opened.');
    }
    return ShareFetchResult.fromMap(decoded);
  }
}
