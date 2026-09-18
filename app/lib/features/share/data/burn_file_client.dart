import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';

/// Calls the three public "Burn Files" Edge Functions directly over HTTPS —
/// no Supabase client, no session — matching [ShareFetchClient]'s pattern
/// exactly, since both uploader and recipient are anonymous by design (see
/// supabase/migrations/20260710050000_burn_files.sql).
class BurnFileClient {
  BurnFileClient._();
  static final BurnFileClient instance = BurnFileClient._();

  static final Uri _initEndpoint =
      Uri.parse('${SupabaseCredentials.url}/functions/v1/burn-file-init');
  static final Uri _confirmEndpoint =
      Uri.parse('${SupabaseCredentials.url}/functions/v1/burn-file-confirm');
  static final Uri _fetchEndpoint =
      Uri.parse('${SupabaseCredentials.url}/functions/v1/burn-file-fetch');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apikey': SupabaseCredentials.anonKey,
      };

  /// Step 1: reserves a file id + signed upload URL. [expiryHours] is
  /// clamped server-side to `burn_files_max_expiry_hours`.
  Future<({String fileId, String signedUploadUrl, String uploadToken})> init({
    required int declaredSizeBytes,
    int? expiryHours,
  }) async {
    final res = await http.post(
      _initEndpoint,
      headers: _headers,
      body: jsonEncode({
        'declared_size_bytes': declaredSizeBytes,
        'expiry_hours': expiryHours,
      }),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(decoded['error'] as String? ?? 'Could not start this upload.');
    }
    return (
      fileId: decoded['file_id'] as String,
      signedUploadUrl: decoded['signed_upload_url'] as String,
      uploadToken: decoded['upload_token'] as String,
    );
  }

  /// Step 2: called after the client's PUT to the signed upload URL
  /// succeeds. The file isn't downloadable by anyone until this returns ok.
  Future<void> confirm(String fileId) async {
    final res = await http.post(
      _confirmEndpoint,
      headers: _headers,
      body: jsonEncode({'file_id': fileId}),
    );
    if (res.statusCode != 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] as String? ?? 'Could not confirm this upload.');
    }
  }

  /// Recipient side: atomically claims the file (single-use — a second call
  /// with the same [fileId] always throws) and returns a short-lived signed
  /// download URL.
  Future<String> fetch(String fileId) async {
    final res = await http.post(
      _fetchEndpoint,
      headers: _headers,
      body: jsonEncode({'file_id': fileId}),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(decoded['error'] as String? ?? 'This link could not be opened.');
    }
    return decoded['signed_url'] as String;
  }
}
