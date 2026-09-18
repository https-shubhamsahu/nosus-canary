// Optional Gemini document insights. Core sharing never calls this.
// Secrets: GEMINI_API_KEY (Supabase Edge Function secret). Never a client key.

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "Gemini is not configured" }, 503);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "Not configured" }, 503);

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) return json({ error: "Sign in required" }, 401);

  let body: { text?: string; question?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const text = String(body.text ?? "").trim();
  if (!text) return json({ error: "Missing text" }, 400);
  if (text.length > 20000) return json({ error: "Text too long" }, 413);

  const question = String(body.question ?? "").trim();
  const prompt = question
    ? `Answer this question about the authorized document. Be brief.\nQuestion: ${question}\n\nDocument:\n${text}`
    : `Summarize this authorized document in 3 short sentences. Then list up to 6 topics as a JSON array.\nReturn JSON: {"summary":"...","topics":["..."]}\n\nDocument:\n${text}`;

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: 400 },
      }),
    },
  );
  if (!geminiRes.ok) {
    return json({ error: "Insight provider unavailable" }, 502);
  }
  const gemini = await geminiRes.json();
  const raw = gemini?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  try {
    const parsed = JSON.parse(String(raw).replace(/^```json\s*|\s*```$/g, ""));
    return json({
      summary: String(parsed.summary ?? raw).trim(),
      topics: Array.isArray(parsed.topics) ? parsed.topics.map(String) : [],
    });
  } catch {
    return json({ summary: String(raw).trim(), topics: [] });
  }
});
