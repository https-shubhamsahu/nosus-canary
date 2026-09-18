import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/share_link.dart';
import '../../domain/repositories/share_repository.dart';
import '../share_fetch_client.dart';

/// Supabase-backed implementation of [ShareRepository].
///
/// Creating/managing links goes straight to Postgres under RLS (only the
/// file's owner may insert a link for it — see the `share_links_insert_owner`
/// policy). Resolving a token for viewing NEVER uses this client's session —
/// that path is deliberately anonymous (see [ShareFetchClient]).
class SupabaseShareRepository implements ShareRepository {
  SupabaseShareRepository(this._client, this._fetchClient);

  final SupabaseClient _client;
  final ShareFetchClient _fetchClient;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Signed-out: sharing requires a session.');
    return id;
  }

  @override
  Future<ShareLink> createShareLink(
    String fileId, {
    bool requireTouchReveal = true,
  }) async {
    final row = await _client
        .from('share_links')
        .insert({
          'file_id': fileId,
          'created_by': _userId,
          'require_touch_reveal': requireTouchReveal,
        })
        .select()
        .single();
    return ShareLink.fromMap(row);
  }

  @override
  Future<List<ShareLink>> myLinksForFile(String fileId) async {
    final rows = await _client
        .from('share_links')
        .select()
        .eq('file_id', fileId)
        .order('created_at', ascending: false);
    return rows.map((r) => ShareLink.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  @override
  Future<void> revokeLink(String linkId) async {
    await _client.from('share_links').update({'revoked': true}).eq('id', linkId);
  }

  @override
  Future<ShareFetchResult> fetchForView({
    required String token,
    required String viewerEmail,
  }) {
    return _fetchClient.fetch(token: token, viewerEmail: viewerEmail);
  }
}
