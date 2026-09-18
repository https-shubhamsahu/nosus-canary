-- Migration: 20260705020000_securesend_share_links.sql
-- SecureSend: anonymous, tracked, watermarked document share links.
--
-- WHY: today only an authenticated group member can read a file (RLS in
-- baseline.sql requires group membership via can_access_storage_object). A
-- share-link recipient has no account and no session. Rather than weaken the
-- existing storage RLS, this is a narrow, additive side door: a random token
-- maps to a file; only the trusted `share-fetch` Edge Function (service role)
-- ever resolves a token to bytes (via a short-lived signed URL). No policy
-- here grants public SELECT on the token table itself.
--
-- Purely additive: touches no existing table, policy, or bucket.

-- ===========================================================================
-- 1. SHARE LINKS
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.share_links (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Unguessable token embedded in the public URL (…/v/<token>). 32 hex chars
    -- of real randomness — never derived from file_id or any sequential value.
    token       TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),
    file_id     TEXT NOT NULL REFERENCES public.secure_files(id) ON DELETE CASCADE,
    created_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    -- Nullable = never expires; default gives new links a sane 30-day life.
    expires_at  TIMESTAMPTZ DEFAULT (timezone('utc', now()) + interval '30 days'),
    revoked     BOOLEAN NOT NULL DEFAULT false,
    -- Nullable = unlimited views.
    max_views   INTEGER,
    view_count  INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_share_links_file_id    ON public.share_links (file_id);
CREATE INDEX IF NOT EXISTS idx_share_links_created_by ON public.share_links (created_by);

ALTER TABLE public.share_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "share_links_select_own" ON public.share_links;
CREATE POLICY "share_links_select_own"
    ON public.share_links FOR SELECT TO authenticated
    USING (created_by = auth.uid());

-- Only the file's OWNER may create a share link for it (not just any group
-- member) — the simplest, least-surprising v1 rule.
DROP POLICY IF EXISTS "share_links_insert_owner" ON public.share_links;
CREATE POLICY "share_links_insert_owner"
    ON public.share_links FOR INSERT TO authenticated
    WITH CHECK (
        created_by = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.secure_files sf
            WHERE sf.id = file_id AND sf.owner_id = auth.uid()
        )
    );

-- Creator can revoke (and only revoke — no other field is client-mutable).
DROP POLICY IF EXISTS "share_links_update_own" ON public.share_links;
CREATE POLICY "share_links_update_own"
    ON public.share_links FOR UPDATE TO authenticated
    USING (created_by = auth.uid())
    WITH CHECK (created_by = auth.uid());

-- ===========================================================================
-- 2. SHARE LINK VIEWS  (append-only view log; the tracking half of the ask)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.share_link_views (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    share_link_id UUID NOT NULL REFERENCES public.share_links(id) ON DELETE CASCADE,
    viewer_email  TEXT NOT NULL,
    viewed_at     TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_share_link_views_link ON public.share_link_views (share_link_id);

ALTER TABLE public.share_link_views ENABLE ROW LEVEL SECURITY;

-- Only the parent link's creator may read the view log. Inserts happen only
-- from share-fetch (service role, bypasses RLS) — never from a client, so
-- viewers can't forge or read each other's view history.
DROP POLICY IF EXISTS "share_link_views_select_owner" ON public.share_link_views;
CREATE POLICY "share_link_views_select_owner"
    ON public.share_link_views FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.share_links sl
            WHERE sl.id = share_link_id AND sl.created_by = auth.uid()
        )
    );

-- ===========================================================================
-- 3. GRANTS  (post-Apr-2026 Supabase projects don't auto-expose new tables)
-- ===========================================================================
GRANT SELECT, INSERT, UPDATE ON public.share_links TO authenticated;
GRANT SELECT ON public.share_link_views TO authenticated;
