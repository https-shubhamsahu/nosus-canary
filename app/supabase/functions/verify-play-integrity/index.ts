// Supabase Edge Function: verify-play-integrity
//
// SCAFFOLDED, NOT VERIFIED END-TO-END. Written to the documented Play
// Integrity API request/response shape and reusing this repo's own proven
// Google service-account JWT pattern (see drive-proxy/index.ts's
// getGoogleAccessToken, which is the same flow against a different Google
// API) — but never exercised against a real device-generated token in this
// environment. Before relying on this:
//   1. Enable the Play Integrity API for the Google Cloud project linked to
//      this app in Play Console (App integrity → Play Integrity API).
//   2. Create a dedicated service account with Play Integrity API access
//      (don't assume GOOGLE_PLAY_SERVICE_ACCOUNT_JSON — used elsewhere for
//      Play publishing — has this scope; verify or create a separate one,
//      matching this codebase's own convention of per-integration service
//      accounts, e.g. drive-proxy's GD_SERVICE_ACCOUNT_EMAIL/GD_PRIVATE_KEY).
//   3. Set PLAY_INTEGRITY_SERVICE_ACCOUNT_EMAIL / PLAY_INTEGRITY_PRIVATE_KEY
//      as Supabase project secrets.
//   4. Fill in the real Cloud project number in PlayIntegrityManager.kt and
//      flip AppIntegrityConfig.enabled on.
//   5. Test against a real device build installed via Play (internal
//      testing track is enough) — sideloaded/debug builds can't mint
//      real tokens.
//
// POST { token, nonce } -> { verdict: {...} } | 4xx/5xx on failure.
// Never blocks the caller on failure — see PlayIntegrityService.requestAndVerify,
// which treats any error here as "no signal", not a hard failure.

import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.13.1/index.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Must match android/app/build.gradle.kts' applicationId exactly.
const PACKAGE_NAME = "foo.nosus.app";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Same shape as drive-proxy/index.ts's getGoogleAccessToken, scoped to
// Play Integrity instead of Drive.
async function getPlayIntegrityAccessToken(email: string, privateKey: string): Promise<string> {
  const cleanedKey = privateKey.replace(/\\n/g, "\n");

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/playintegrity",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(email)
    .setSubject(email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(await importPKCS8(cleanedKey, "RS256"));

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google OAuth exchange failed: ${await response.text()}`);
  }
  const data = await response.json();
  return data.access_token;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const serviceAccountEmail = Deno.env.get("PLAY_INTEGRITY_SERVICE_ACCOUNT_EMAIL");
  const serviceAccountKey = Deno.env.get("PLAY_INTEGRITY_PRIVATE_KEY");
  if (!serviceAccountEmail || !serviceAccountKey) {
    return json({ error: "verify-play-integrity is not configured" }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const token = String(body.token ?? "").trim();
  const expectedNonce = String(body.nonce ?? "").trim();
  if (!token || !expectedNonce) {
    return json({ error: "Missing token or nonce" }, 400);
  }

  try {
    const accessToken = await getPlayIntegrityAccessToken(serviceAccountEmail, serviceAccountKey);

    const decodeRes = await fetch(
      `https://playintegrity.googleapis.com/v1/${PACKAGE_NAME}:decodeIntegrityToken`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ integrity_token: token }),
      },
    );

    if (!decodeRes.ok) {
      return json({ error: `Play Integrity decode failed: ${await decodeRes.text()}` }, 502);
    }

    const decoded = await decodeRes.json();
    const payload = decoded.tokenPayloadExternal ?? {};
    const requestDetails = payload.requestDetails ?? {};

    // Reject if the nonce doesn't match what THIS request minted, or the
    // token was issued for a different app — both prevent a captured token
    // from a different session/app being replayed here.
    if (requestDetails.nonce !== expectedNonce) {
      return json({ error: "Nonce mismatch — possible replay" }, 400);
    }
    if (requestDetails.requestPackageName !== PACKAGE_NAME) {
      return json({ error: "Package name mismatch" }, 400);
    }

    return json({
      verdict: {
        appIntegrity: payload.appIntegrity ?? null,
        deviceIntegrity: payload.deviceIntegrity ?? null,
        accountDetails: payload.accountDetails ?? null,
      },
    });
  } catch (error) {
    console.error("verify-play-integrity: verification failed", error);
    return json({ error: "Could not verify integrity token" }, 500);
  }
});
