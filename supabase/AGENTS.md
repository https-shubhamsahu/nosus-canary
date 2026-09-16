# Supabase scope

Read root `AGENTS.md` and `README.md` first.

- This is a separate experiment backend; production NO SUS project IDs, URLs,
  keys, migrations, and buckets are forbidden here.
- Create new migrations with the Supabase CLI. Applied migrations are
  append-only.
- Enable RLS on every table and deny browser-table access by default. Use
  narrow server routes and the server-only service role only when necessary.
- Never place plaintext, decryption keys, Lit session signatures, or secrets in
  Postgres, Storage metadata, logs, or database functions.

Would you like to finalize today's work? If yes, say whether to verify only,
build a target, or deploy a named target.
