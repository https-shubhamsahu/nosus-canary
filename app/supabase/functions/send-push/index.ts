// Delivers queued rows from `public.notifications` to FCM.
//
// Invoked as a sweep (cron or manual) rather than per-insert: a push provider
// is the least reliable dependency in the stack, and a sweep that re-reads
// `pushed_at IS NULL` is naturally idempotent, whereas a per-row webhook drops
// the notification permanently the one time FCM 503s.
//
// STATUS: structurally complete, never exercised against a real FCM project.
// It needs FCM_SERVICE_ACCOUNT_EMAIL / FCM_PRIVATE_KEY / FCM_PROJECT_ID, which
// are not set — see AGENTS.md §8. Do NOT assume the Play publishing service
// account (GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) covers this: FCM needs the
// firebase.messaging scope, so it takes its own service account, same
// convention as drive-proxy's GD_SERVICE_ACCOUNT_EMAIL.
//
// Until those exist this returns a 503 describing exactly what is missing,
// which is the honest response — not a 200 that implies delivery happened.
//
// Deployed with verify_jwt disabled but guarded by PUSH_SWEEP_SECRET: the
// caller is a scheduler, not a user session. Without that secret set, the
// function refuses to run rather than defaulting open.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.13.1/index.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-sweep-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Max rows per sweep. Bounds both the FCM fan-out and the function's runtime. */
const BATCH_SIZE = 200;

async function getFcmAccessToken(
  email: string,
  privateKey: string,
): Promise<string> {
  const cleanedKey = privateKey.replace(/\\n/g, "\n");

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
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
    throw new Error(`FCM OAuth exchange failed: ${await response.text()}`);
  }
  return (await response.json()).access_token;
}

interface QueuedNotification {
  id: string;
  user_id: string;
  category: string;
  title: string;
  body: string;
  deep_link: string | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (payload: unknown, status: number) =>
    new Response(JSON.stringify(payload), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  const sweepSecret = Deno.env.get("PUSH_SWEEP_SECRET");
  if (!sweepSecret) {
    return json(
      {
        error: "Push delivery is not configured.",
        setupInstructions:
          "Set PUSH_SWEEP_SECRET, FCM_SERVICE_ACCOUNT_EMAIL, FCM_PRIVATE_KEY and " +
          "FCM_PROJECT_ID in Supabase project secrets. See AGENTS.md §8.",
      },
      503,
    );
  }
  if (req.headers.get("x-sweep-secret") !== sweepSecret) {
    return json({ error: "Forbidden" }, 403);
  }

  const fcmEmail = Deno.env.get("FCM_SERVICE_ACCOUNT_EMAIL");
  const fcmKey = Deno.env.get("FCM_PRIVATE_KEY");
  const fcmProject = Deno.env.get("FCM_PROJECT_ID");
  if (!fcmEmail || !fcmKey || !fcmProject) {
    return json(
      {
        error: "FCM credentials are not configured.",
        setupInstructions:
          "Set FCM_SERVICE_ACCOUNT_EMAIL, FCM_PRIVATE_KEY and FCM_PROJECT_ID.",
      },
      503,
    );
  }

  // Service role: this reads rows belonging to every user by design, which is
  // exactly why the function is secret-gated above and never user-invocable.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: pending, error: fetchError } = await supabase
    .from("notifications")
    .select("id, user_id, category, title, body, deep_link")
    .is("pushed_at", null)
    .order("created_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (fetchError) {
    return json({ error: fetchError.message }, 500);
  }
  if (!pending || pending.length === 0) {
    return json({ delivered: 0, message: "Nothing queued." }, 200);
  }

  const notifications = pending as QueuedNotification[];
  const userIds = [...new Set(notifications.map((n) => n.user_id))];

  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("token, user_id")
    .in("user_id", userIds);

  const tokensByUser = new Map<string, string[]>();
  for (const row of tokenRows ?? []) {
    const list = tokensByUser.get(row.user_id) ?? [];
    list.push(row.token);
    tokensByUser.set(row.user_id, list);
  }

  const accessToken = await getFcmAccessToken(fcmEmail, fcmKey);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${fcmProject}/messages:send`;

  const deliveredIds: string[] = [];
  const staleTokens: string[] = [];

  for (const notification of notifications) {
    const tokens = tokensByUser.get(notification.user_id) ?? [];

    // No registered device is not a failure — the user may only ever use the
    // web app. Mark it pushed so the sweep does not reconsider it forever; the
    // row is still in their in-app inbox.
    if (tokens.length === 0) {
      deliveredIds.push(notification.id);
      continue;
    }

    for (const token of tokens) {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            // title/body come straight from the DB, where enqueue_notification
            // composed them from fixed templates that name no document and no
            // group. Nothing sensitive is added here, because this payload is
            // what renders on a locked screen.
            notification: {
              title: notification.title,
              body: notification.body,
            },
            data: {
              category: notification.category,
              deep_link: notification.deep_link ?? "",
              notification_id: notification.id,
            },
            android: {
              priority: notification.category === "security" ? "HIGH" : "NORMAL",
              notification: {
                channel_id: `nosus_${notification.category}`,
                // Collapse noisy categories so ten new documents are one line,
                // not ten. Security alerts never collapse.
                tag: notification.category === "security"
                  ? undefined
                  : notification.category,
              },
            },
          },
        }),
      });

      if (response.ok) continue;

      // 404 UNREGISTERED / 400 INVALID_ARGUMENT on the token mean the install
      // is gone. Reap it so the list does not grow forever with dead handsets.
      if (response.status === 404 || response.status === 400) {
        staleTokens.push(token);
      }
    }

    deliveredIds.push(notification.id);
  }

  if (deliveredIds.length > 0) {
    await supabase
      .from("notifications")
      .update({ pushed_at: new Date().toISOString() })
      .in("id", deliveredIds);
  }

  if (staleTokens.length > 0) {
    await supabase.from("device_tokens").delete().in("token", staleTokens);
  }

  return json(
    { delivered: deliveredIds.length, reapedTokens: staleTokens.length },
    200,
  );
});
