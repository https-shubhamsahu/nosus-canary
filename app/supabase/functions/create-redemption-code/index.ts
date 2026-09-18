// Supabase Edge Function: create-redemption-code
//
// Mints a short, human-typeable code as an ALTERNATE way to retrieve the
// key/IV for an existing Burn Note or Burn File — the link-based path (key/
// IV in the URL fragment, never touching the server) is unaffected and
// keeps its zero-knowledge guarantee. This is a deliberate, informed
// exception for this one path: the server temporarily holds the key,
// indexed by a hash of the code, for a short window.
// See supabase/migrations/20260713000000_burn_redemption_codes.sql for the
// full design rationale.
//
// POST { target_kind: 'note'|'file', target_id, key_hex, iv_hex } ->
//   { code, redeem_token, expires_at }
//
// Responsibilities:
//   1. Check the burn_redemption_codes_enabled kill-switch.
//   2. Verify the target actually exists and hasn't already been
//      consumed/expired — no point minting a code for dead content.
//   3. Generate a two-digit human confirmation code AND a 256-bit redeem
//      token. The token is the actual credential; the code is intentionally
//      only a convenient pairing check.
//   4. Hash both values and store them with expiry capped to the underlying
//      content's own expiry. Return plaintext values once.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TOKEN_BYTES = 32;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function hmacHex(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function generatePairingCode(): string {
  // Rejection sampling avoids modulo bias: every value 00–99 has equal odds.
  const byte = new Uint8Array(1);
  do crypto.getRandomValues(byte); while (byte[0] >= 200);
  return String(byte[0] % 100).padStart(2, "0");
}

function generateRedeemToken(): string {
  const bytes = new Uint8Array(TOKEN_BYTES);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const codeSalt = Deno.env.get("REDEMPTION_CODE_SALT");
  if (!supabaseUrl || !serviceRoleKey || !codeSalt) {
    return json({ error: "create-redemption-code is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const targetKind = String(body.target_kind ?? "");
  const targetId = String(body.target_id ?? "").trim();
  const keyHex = String(body.key_hex ?? "").trim();
  const ivHex = String(body.iv_hex ?? "").trim();
  if (targetKind !== "note" && targetKind !== "file") {
    return json({ error: "target_kind must be 'note' or 'file'" }, 400);
  }
  if (!targetId || !keyHex || !ivHex) {
    return json({ error: "Missing target_id, key_hex, or iv_hex" }, 400);
  }
  if (
    !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(targetId) ||
    !/^[0-9a-f]{64}$/i.test(keyHex) ||
    !/^[0-9a-f]{32}$/i.test(ivHex)
  ) {
    return json({ error: "Invalid redemption target" }, 400);
  }

  const { data: flag } = await admin
    .from("feature_flags")
    .select("is_active")
    .eq("flag_key", "burn_redemption_codes_enabled")
    .maybeSingle();
  if (flag && flag.is_active === false) {
    return json({ error: "Redemption codes are temporarily disabled" }, 503);
  }

  const { data: configRows } = await admin
    .from("remote_configs")
    .select("config_key, config_value")
    .eq("config_key", "redeem_code_ttl_minutes");
  const ttlMinutes = configRows?.length ? Number(configRows[0].config_value) : 20;

  // Verify the target still exists and hasn't already been consumed/expired
  // — a code for dead content would just be a confusing dead end.
  let targetExpiresAt: string | null = null;
  if (targetKind === "file") {
    const { data: fileRow } = await admin
      .from("burn_files")
      .select("expires_at, consumed_at")
      .eq("id", targetId)
      .maybeSingle();
    if (!fileRow || fileRow.consumed_at || new Date(fileRow.expires_at) <= new Date()) {
      return json({ error: "This file is no longer available" }, 404);
    }
    targetExpiresAt = fileRow.expires_at;
  } else {
    const { data: noteRow } = await admin
      .from("burn_notes")
      .select("expires_at")
      .eq("id", targetId)
      .maybeSingle();
    if (!noteRow || new Date(noteRow.expires_at) <= new Date()) {
      return json({ error: "This note is no longer available" }, 404);
    }
    targetExpiresAt = noteRow.expires_at;
  }

  const ttlExpiry = new Date(Date.now() + ttlMinutes * 60 * 1000);
  const targetExpiry = new Date(targetExpiresAt);
  const expiresAt = (ttlExpiry < targetExpiry ? ttlExpiry : targetExpiry).toISOString();

  const code = generatePairingCode();
  const redeemToken = generateRedeemToken();
  const [codeHash, redeemTokenHash] = await Promise.all([
    hmacHex(code, codeSalt),
    hmacHex(redeemToken, codeSalt),
  ]);

  const { error: insertErr } = await admin.from("burn_redemption_codes").insert({
    code_hash: codeHash,
    redeem_token_hash: redeemTokenHash,
    target_kind: targetKind,
    target_id: targetId,
    key_hex: keyHex,
    iv_hex: ivHex,
    expires_at: expiresAt,
  });

  if (insertErr) {
    console.error("create-redemption-code: failed to insert row", insertErr);
    return json({ error: "Could not create a redemption pairing" }, 502);
  }

  return json({ code, redeem_token: redeemToken, expires_at: expiresAt });
});
