-- Migration: 20260705010000_sealed_seals_membership_check.sql
-- Hardens seals_insert_own: a seal write now also requires arena membership.
--
-- WHY: sealChoice moved to a direct client write (Flutter inserts the
-- ciphertext straight into `seals` after encrypting via the arena pact key),
-- bypassing the membership/target-existence checks a trusted orchestrator
-- would otherwise perform. RLS previously only checked `sealer_id = auth.uid()`
-- for INSERT, so any authenticated user could insert a seal row into an arena
-- they never joined (a dead, permanently-unmatchable row — not a data leak,
-- but wasted state worth closing off at the RLS layer, defense-in-depth).
--
-- Purely additive: replaces one policy on `public.seals`; no other table,
-- policy, or RPC is touched.

DROP POLICY IF EXISTS "seals_insert_own" ON public.seals;
CREATE POLICY "seals_insert_own"
    ON public.seals FOR INSERT TO authenticated
    WITH CHECK (sealer_id = auth.uid() AND public.is_arena_member(arena_id));
