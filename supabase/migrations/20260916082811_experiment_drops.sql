-- NO SUS — Monad Experiment. Separate project only; never apply to production NO SUS.
-- The browser never writes these tables directly. Server-side event indexing and
-- encrypted-payload persistence use the service role after on-chain validation.

create table if not exists public.experiment_drops (
  id text primary key check (id ~ '^0x[0-9a-f]{64}$'),
  sender_wallet text not null check (sender_wallet ~ '^0x[0-9a-f]{40}$'),
  recipient_wallet text check (recipient_wallet is null or recipient_wallet ~ '^0x[0-9a-f]{40}$'),
  opener_wallet text check (opener_wallet is null or opener_wallet ~ '^0x[0-9a-f]{40}$'),
  ciphertext_digest text not null check (ciphertext_digest ~ '^0x[0-9a-f]{64}$'),
  ciphertext_payload text not null,
  lit_metadata jsonb not null check (jsonb_typeof(lit_metadata) = 'object'),
  storage_path text unique,
  expires_at timestamptz,
  sealed_tx_hash text unique check (sealed_tx_hash is null or sealed_tx_hash ~ '^0x[0-9a-f]{64}$'),
  opened_tx_hash text unique check (opened_tx_hash is null or opened_tx_hash ~ '^0x[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  opened_at timestamptz,
  constraint acknowledged_drop_has_opener check (
    (opened_at is null and opener_wallet is null and opened_tx_hash is null)
    or (opened_at is not null and opener_wallet is not null and opened_tx_hash is not null)
  )
);

create table if not exists public.experiment_drop_events (
  id bigint generated always as identity primary key,
  drop_id text not null references public.experiment_drops(id) on delete cascade,
  event_type text not null check (event_type in ('sealed', 'opened')),
  actor_wallet text not null check (actor_wallet ~ '^0x[0-9a-f]{40}$'),
  transaction_hash text not null check (transaction_hash ~ '^0x[0-9a-f]{64}$'),
  block_number bigint not null check (block_number >= 0),
  event_at timestamptz not null default now(),
  unique (transaction_hash, event_type)
);

create index if not exists experiment_drops_created_at_idx
  on public.experiment_drops (created_at desc);
create index if not exists experiment_drops_opened_at_idx
  on public.experiment_drops (opened_at desc nulls last);
create index if not exists experiment_drop_events_drop_id_idx
  on public.experiment_drop_events (drop_id, event_at desc);

alter table public.experiment_drops enable row level security;
alter table public.experiment_drop_events enable row level security;

-- No anon/authenticated policy is intentional. The only browser-safe reads are
-- the explicit, allow-listed Next.js routes; service-role callers bypass RLS.
revoke all on table public.experiment_drops from anon, authenticated;
revoke all on table public.experiment_drop_events from anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'encrypted-drops',
  'encrypted-drops',
  false,
  1048576,
  array['application/octet-stream', 'application/json']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Private by default: no storage.objects policies are created for anon or
-- authenticated. The server validates then uses the service role for writes.
comment on table public.experiment_drops is
  'Encrypted-drop metadata for the Monad testnet experiment. Never stores plaintext or decryption keys.';
comment on table public.experiment_drop_events is
  'Indexed Sealed and OpenAcknowledged events for the public Receipt Wall.';
