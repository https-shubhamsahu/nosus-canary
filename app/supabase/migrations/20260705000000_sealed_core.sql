-- Migration: 20260705000000_sealed_core.sql
-- Sealed — reciprocity-gated intent graph. Core schema (M0).
--
-- ARCHITECTURE / TRUST NOTES (read before changing)
--   * Sealed's unit is an ARENA (a community/room). Each member gets a small,
--     PUBLIC integer id (`arena_public_id`). A SEAL is a member's ENCRYPTED
--     choice: the ciphertext of the arena_public_id of the ONE person they
--     picked (or a sentinel 0 = "no pick"). A MATCH exists for a pair (A,B) iff
--         (A's choice == B.public_id) AND (B's choice == A.public_id)
--     which the FHE pact evaluator computes over ciphertext
--     (services/fhe-compute/src/compute/pact.rs). The predicate needs BOTH
--     choices sealed under the SAME arena key — hence a per-arena key, NOT the
--     per-user FHE keys used elsewhere.
--   * `arenas.public_key` holds the arena's non-secret CompactPublicKey so
--     members can encrypt their choice ON-DEVICE (the trustless M10 path). The
--     interim MVP may encrypt server-side; either way this schema is stable.
--   * PRIVACY (load-bearing): a seal's target is NEVER stored in plaintext — it
--     lives only inside `sealed_choice` (ciphertext). RLS makes a member's seal
--     selectable ONLY by that member. The matcher runs as service_role.
--   * HONESTY RULE: until M10 the pact key may be held server-side, so copy says
--     "encrypted, revealed only on mutual match" — NOT "we cannot see it".
--   * Purely ADDITIVE: touches no existing NO SUS table, policy, or RPC.

-- ===========================================================================
-- 1. SEALED PROFILES  (consumer identity layer over auth.users)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.sealed_profiles (
    user_id       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    handle        TEXT UNIQUE,                 -- public @handle for discovery
    display_name  TEXT,
    avatar_url    TEXT,
    -- SHA-256 of a normalized phone/email, for contact-based discovery WITHOUT
    -- storing raw contacts. Not secret; not reversible to the contact.
    contact_hash  TEXT,
    age_ok        BOOLEAN NOT NULL DEFAULT false,   -- age-gate (M5)
    created_at    TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);
CREATE INDEX IF NOT EXISTS idx_sealed_profiles_handle       ON public.sealed_profiles (handle);
CREATE INDEX IF NOT EXISTS idx_sealed_profiles_contact_hash ON public.sealed_profiles (contact_hash);

ALTER TABLE public.sealed_profiles ENABLE ROW LEVEL SECURITY;
-- Profiles are discoverable (you must be able to find who to seal), but only
-- the owner may write their own row.
DROP POLICY IF EXISTS "sealed_profiles_select_all" ON public.sealed_profiles;
CREATE POLICY "sealed_profiles_select_all"
    ON public.sealed_profiles FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "sealed_profiles_upsert_own" ON public.sealed_profiles;
CREATE POLICY "sealed_profiles_insert_own"
    ON public.sealed_profiles FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "sealed_profiles_update_own" ON public.sealed_profiles;
CREATE POLICY "sealed_profiles_update_own"
    ON public.sealed_profiles FOR UPDATE TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ===========================================================================
-- 2. ARENAS  (matching contexts; shared pact key per arena)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.arenas (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           TEXT NOT NULL,
    kind           TEXT NOT NULL DEFAULT 'community'
                   CHECK (kind IN ('community','pairwise')),
    -- Non-secret CompactPublicKey (base64) enabling on-device encryption.
    -- Nullable while a key is being provisioned / in interim server-side mode.
    public_key     TEXT,
    key_fingerprint TEXT,                       -- SHA-256 of the eval key
    created_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE public.arenas ENABLE ROW LEVEL SECURITY;
-- Members (and, for open communities, any authenticated user who can join)
-- may read the arena. Writes go through RPCs / service_role.
DROP POLICY IF EXISTS "arenas_select_member" ON public.arenas;
CREATE POLICY "arenas_select_member"
    ON public.arenas FOR SELECT TO authenticated USING (true);

-- ===========================================================================
-- 3. ARENA MEMBERS  (public integer id per member, unique within an arena)
-- ===========================================================================
-- Helper must exist BEFORE the arena_members policy that references it
-- (Postgres validates policy expressions at creation time).
CREATE OR REPLACE FUNCTION public.is_arena_member(p_arena_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.arena_members
    WHERE arena_id = p_arena_id AND user_id = auth.uid()
  );
END;
$$;

CREATE TABLE IF NOT EXISTS public.arena_members (
    arena_id        UUID NOT NULL REFERENCES public.arenas(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    arena_public_id INTEGER NOT NULL,           -- PUBLIC; used by the predicate
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    PRIMARY KEY (arena_id, user_id),
    UNIQUE (arena_id, arena_public_id)
);
CREATE INDEX IF NOT EXISTS idx_arena_members_user ON public.arena_members (user_id);

ALTER TABLE public.arena_members ENABLE ROW LEVEL SECURITY;
-- Membership + public ids are not secret (the predicate uses public ids), so
-- members of an arena can see the roster to know who to seal.
DROP POLICY IF EXISTS "arena_members_select" ON public.arena_members;
CREATE POLICY "arena_members_select"
    ON public.arena_members FOR SELECT TO authenticated
    USING (public.is_arena_member(arena_id));

-- ===========================================================================
-- 4. SEALS  (encrypted one-directional choices)  ***RLS is load-bearing***
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.seals (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    arena_id      UUID NOT NULL REFERENCES public.arenas(id) ON DELETE CASCADE,
    sealer_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    -- The pick, ENCRYPTED (base64 TFHE ciphertext under the arena key). The
    -- target is NEVER stored in plaintext anywhere.
    sealed_choice TEXT NOT NULL,
    intent_kind   TEXT NOT NULL DEFAULT 'crush'
                  CHECK (intent_kind IN
                    ('crush','friend','reconnect','work_with','hire','invest','partner')),
    -- Someday List (M4): seals do not expire and re-evaluate against future
    -- counter-seals unless explicitly withdrawn.
    never_expires BOOLEAN NOT NULL DEFAULT true,
    status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','matched','withdrawn')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    -- one active seal per (sealer, arena, intent); re-sealing updates it
    UNIQUE (arena_id, sealer_id, intent_kind)
);
CREATE INDEX IF NOT EXISTS idx_seals_arena  ON public.seals (arena_id);
CREATE INDEX IF NOT EXISTS idx_seals_sealer ON public.seals (sealer_id);

ALTER TABLE public.seals ENABLE ROW LEVEL SECURITY;
-- CRITICAL: a member can see and manage ONLY their own seals. No policy lets
-- anyone read a counterparty's seal. The matcher reads seals as service_role
-- (which bypasses RLS) and never exposes a non-mutual choice to a client.
DROP POLICY IF EXISTS "seals_select_own" ON public.seals;
CREATE POLICY "seals_select_own"
    ON public.seals FOR SELECT TO authenticated USING (sealer_id = auth.uid());
DROP POLICY IF EXISTS "seals_insert_own" ON public.seals;
CREATE POLICY "seals_insert_own"
    ON public.seals FOR INSERT TO authenticated WITH CHECK (sealer_id = auth.uid());
DROP POLICY IF EXISTS "seals_update_own" ON public.seals;
CREATE POLICY "seals_update_own"
    ON public.seals FOR UPDATE TO authenticated
    USING (sealer_id = auth.uid()) WITH CHECK (sealer_id = auth.uid());

-- ===========================================================================
-- 5. MATCHES  (created only on a true FHE decrypt; visible to both parties)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.matches (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    arena_id    UUID NOT NULL REFERENCES public.arenas(id) ON DELETE CASCADE,
    user_a      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_b      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    intent_kind TEXT NOT NULL,
    matched_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    -- exactly one match per unordered pair per arena+intent
    CONSTRAINT matches_pair_unique UNIQUE (arena_id, intent_kind, user_a, user_b),
    CONSTRAINT matches_ordered CHECK (user_a < user_b)
);
CREATE INDEX IF NOT EXISTS idx_matches_user_a ON public.matches (user_a);
CREATE INDEX IF NOT EXISTS idx_matches_user_b ON public.matches (user_b);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
-- Only the two matched parties can see the match. Inserts are service_role only
-- (the matcher); no client INSERT/UPDATE/DELETE policy exists.
DROP POLICY IF EXISTS "matches_select_participant" ON public.matches;
CREATE POLICY "matches_select_participant"
    ON public.matches FOR SELECT TO authenticated
    USING (auth.uid() = user_a OR auth.uid() = user_b);

-- ===========================================================================
-- 6. INVITES  (the viral loop: seal toward a non-user -> shareable claim link)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.invites (
    code        TEXT PRIMARY KEY,               -- random, unguessable
    inviter_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    arena_id    UUID REFERENCES public.arenas(id) ON DELETE SET NULL,
    -- optional contact_hash of the intended recipient (never the raw contact)
    target_hint TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    claimed_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    claimed_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_invites_inviter ON public.invites (inviter_id);

ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;
-- Inviter manages own invites; claiming happens via an RPC (M3) so we never
-- expose the whole invite table. A public claim-by-code path is added in M3.
DROP POLICY IF EXISTS "invites_select_own" ON public.invites;
CREATE POLICY "invites_select_own"
    ON public.invites FOR SELECT TO authenticated USING (inviter_id = auth.uid());
DROP POLICY IF EXISTS "invites_insert_own" ON public.invites;
CREATE POLICY "invites_insert_own"
    ON public.invites FOR INSERT TO authenticated WITH CHECK (inviter_id = auth.uid());

-- ===========================================================================
-- 7. HELPERS & RPCs
-- ===========================================================================
-- (is_arena_member is defined in section 3, before the policy that uses it.)

-- Atomically join an arena, assigning the next free public id. Idempotent:
-- returns the caller's existing public id if already a member.
CREATE OR REPLACE FUNCTION public.join_arena(p_arena_id uuid)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_pub  integer;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT arena_public_id INTO v_pub
  FROM public.arena_members WHERE arena_id = p_arena_id AND user_id = v_user;
  IF v_pub IS NOT NULL THEN RETURN v_pub; END IF;

  -- next public id starts at 1 (0 is reserved as the "no pick" sentinel)
  SELECT COALESCE(MAX(arena_public_id), 0) + 1 INTO v_pub
  FROM public.arena_members WHERE arena_id = p_arena_id;

  INSERT INTO public.arena_members (arena_id, user_id, arena_public_id)
  VALUES (p_arena_id, v_user, v_pub)
  ON CONFLICT (arena_id, user_id) DO NOTHING;

  SELECT arena_public_id INTO v_pub
  FROM public.arena_members WHERE arena_id = p_arena_id AND user_id = v_user;
  RETURN v_pub;
END;
$$;

-- Keep updated_at fresh on seals (reuses the existing fhe_touch pattern).
DROP TRIGGER IF EXISTS trg_seals_touch ON public.seals;
CREATE TRIGGER trg_seals_touch
    BEFORE UPDATE ON public.seals
    FOR EACH ROW EXECUTE FUNCTION public.fhe_touch_updated_at();

-- ===========================================================================
-- 8. GRANTS + REALTIME
-- ===========================================================================
-- Explicit grants (post-Apr-2026 projects don't auto-expose new tables).
GRANT SELECT, INSERT, UPDATE ON public.sealed_profiles TO authenticated;
GRANT SELECT ON public.arenas TO authenticated;
GRANT SELECT ON public.arena_members TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.seals TO authenticated;
GRANT SELECT ON public.matches TO authenticated;
GRANT SELECT, INSERT ON public.invites TO authenticated;

-- The reveal moment: clients subscribe to matches (RLS-scoped to participants)
-- and their own seals (status flips to 'matched').
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
      EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.seals;
      EXCEPTION WHEN duplicate_object THEN NULL; END;
  END IF;
END $$;
