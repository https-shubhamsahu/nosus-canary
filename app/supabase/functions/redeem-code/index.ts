// Supabase Edge Function: redeem-code
//
// The recipient's entry point for the short-code retrieval path — see
// create-redemption-code and
// supabase/migrations/20260713000000_burn_redemption_codes.sql for the full
// design. Public on purpose (verify_jwt: false), same anonymous posture as
// burn-file-fetch/read_and_burn_note — a recipient never needs an account.
//
// POST { code, redeem_token? } -> { target_kind, target_id, key_hex, iv_hex }
//                 | 410 if invalid/expired/already-used (one generic error —
//                   deliberately not distinguishing wrong-vs-expired-vs-used,
//                   so a guesser gets no oracle signal)
//
// Rate-limited by a salted hash of the request IP (never the raw IP),
// mirroring burn-file-init's limiter — defense-in-depth against a
// scripted/distributed brute-force attempt. New two-digit values are never a
// standalone credential: they must be paired with an unguessable 256-bit
// redeem token from the secure link. Legacy eight-character codes remain
// redeemable briefly for backwards compatibility.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const codeSalt = Deno.env.get("REDEMPTION_CODE_SALT");
  const ipSalt = Deno.env.get("BURN_FILES_IP_SALT");
  if (!supabaseUrl || !serviceRoleKey || !codeSalt || !ipSalt) {
    return json({ error: "redeem-code is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const code = String(body.code ?? "").trim().toUpperCase();
  const redeemToken = String(body.redeem_token ?? "").trim().toLowerCase();
  if (!code) return json({ error: "Missing code" }, 400);
  const isPairingCode = /^\d{2}$/.test(code);
  const hasRedeemToken = /^[0-9a-f]{64}$/.test(redeemToken);
  if (isPairingCode && !hasRedeemToken) {
    return json({ error: "Open the secure pairing link before entering this two-digit code" }, 400);
  }
  if (redeemToken && !hasRedeemToken) {
    return json({ error: "Invalid pairing link" }, 400);
  }
  if (!isPairingCode && !/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/.test(code)) {
    return json({ error: "Invalid or expired code" }, 410);
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
    .in("config_key", ["redeem_rate_limit_per_hour", "redeem_rate_limit_window_minutes"]);
  const cfg = (key: string, fallback: number): number => {
    const row = configRows?.find((r: any) => r.config_key === key);
    return row ? Number(row.config_value) : fallback;
  };
  const rateLimitPerHour = cfg("redeem_rate_limit_per_hour", 10);
  const rateLimitWindowMinutes = cfg("redeem_rate_limit_window_minutes", 60);

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const ipHash = await hmacHex(ip, ipSalt);

  const { data: allowed, error: rateErr } = await admin.rpc("check_and_increment_redeem_rate", {
    p_ip_hash: ipHash,
    p_limit: rateLimitPerHour,
    p_window_minutes: rateLimitWindowMinutes,
  });
  if (rateErr) {
    console.error("redeem-code: rate limit check failed", rateErr);
    return json({ error: "Could not process this code" }, 500);
  }
  if (!allowed) {
    return json({ error: "Too many attempts from this network. Please try again later." }, 429);
  }

  const codeHash = await hmacHex(code, codeSalt);
  const tokenHash = hasRedeemToken
    ? await hmacHex(redeemToken, codeSalt)
    : null;
  const { data: claimed, error: claimErr } = hasRedeemToken
    ? await admin.rpc("claim_redemption_code", {
      p_code_hash: codeHash,
      p_redeem_token_hash: tokenHash,
    })
    : await admin.rpc("claim_redemption_code", { p_code_hash: codeHash });
  if (claimErr) {
    console.error("redeem-code: claim RPC failed", claimErr);
    return json({ error: "Could not process this code" }, 500);
  }
  if (!claimed?.id) {
    return json({ error: "Invalid or expired code" }, 410);
  }

  return json({
    target_kind: claimed.target_kind,
    target_id: claimed.target_id,
    key_hex: claimed.key_hex,
    iv_hex: claimed.iv_hex,
  });
});
