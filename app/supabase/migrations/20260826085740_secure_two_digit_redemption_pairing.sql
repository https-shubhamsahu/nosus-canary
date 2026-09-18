-- Two-digit redemption pairing
--
-- The old eight-character code was the only credential for the alternate
-- redemption flow. A two-digit value cannot safely carry that responsibility.
-- New rows therefore bind the human-friendly 00–99 confirmation code to a
-- random 256-bit link token. The link token is the authorization boundary;
-- the two digits merely confirm that the recipient and sender are referring
-- to the same share. Existing short codes keep working until their normal
-- short expiry so links already sent are not broken.

ALTER TABLE public.burn_redemption_codes
  ADD COLUMN IF NOT EXISTS redeem_token_hash TEXT;

-- `code_hash` used to be globally unique. That was appropriate when the
-- eight-character code was the credential, but it would cap the two-digit
-- flow at 100 lifetime rows. New pairings are unique by code + secret token;
-- legacy rows retain their one-code uniqueness while they age out.
ALTER TABLE public.burn_redemption_codes
  DROP CONSTRAINT IF EXISTS burn_redemption_codes_code_hash_key;

CREATE UNIQUE INDEX IF NOT EXISTS burn_redemption_codes_pairing_key_idx
  ON public.burn_redemption_codes (code_hash, redeem_token_hash)
  WHERE redeem_token_hash IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS burn_redemption_codes_legacy_code_idx
  ON public.burn_redemption_codes (code_hash)
  WHERE redeem_token_hash IS NULL;

-- Keep the legacy function safe if it is called by an older deployed client:
-- it can only consume the pre-pairing rows that have no link token.
CREATE OR REPLACE FUNCTION public.claim_redemption_code(p_code_hash text)
RETURNS public.burn_redemption_codes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_redemption_codes;
BEGIN
  UPDATE public.burn_redemption_codes
     SET consumed_at = now()
   WHERE code_hash = p_code_hash
     AND redeem_token_hash IS NULL
     AND consumed_at IS NULL
     AND expires_at > now()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- The pairing-aware claim is atomic: both the opaque link token and the
-- two-digit confirmation must match the same still-live row.
CREATE OR REPLACE FUNCTION public.claim_redemption_code(
  p_code_hash text,
  p_redeem_token_hash text
)
RETURNS public.burn_redemption_codes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_redemption_codes;
BEGIN
  UPDATE public.burn_redemption_codes
     SET consumed_at = now()
   WHERE code_hash = p_code_hash
     AND redeem_token_hash = p_redeem_token_hash
     AND consumed_at IS NULL
     AND expires_at > now()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_redemption_code(text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_redemption_code(text, text)
  FROM PUBLIC, anon, authenticated;
