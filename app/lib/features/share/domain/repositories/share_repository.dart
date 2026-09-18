import '../entities/share_link.dart';

/// Domain contract for SecureSend share links. Implementations live in `data/`.
abstract class ShareRepository {
  /// Creates a share link for [fileId] (caller must own the file — enforced
  /// by RLS). Returns the created link, whose `token` is embedded in the
  /// public URL shown to the sender.
  ///
  /// [requireTouchReveal] is the sender's own choice, made at share time: if
  /// false, the recipient sees the document immediately with no blur/touch
  /// gate (still watermarked and view-logged either way).
  Future<ShareLink> createShareLink(
    String fileId, {
    bool requireTouchReveal = true,
  });

  /// The caller's own links for a file (own-links only, per RLS).
  Future<List<ShareLink>> myLinksForFile(String fileId);

  /// Revokes a link the caller created.
  Future<void> revokeLink(String linkId);

  /// Anonymous resolution of a token into a viewable document. No Supabase
  /// session is used or required — this call authenticates with the token
  /// alone, exactly as a signed-out recipient would.
  Future<ShareFetchResult> fetchForView({
    required String token,
    required String viewerEmail,
  });
}
