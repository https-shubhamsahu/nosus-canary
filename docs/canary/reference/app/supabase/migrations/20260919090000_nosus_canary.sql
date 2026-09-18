-- NO SUS Canary — experiment project ffidvfguojalzpclipzi ONLY.
-- Never apply to production (rxfnazmusofikwaggntb).
--
-- The server stores encrypted copies it cannot read, which device (hashed)
-- and name opened which copy, and Monad transaction hashes. It never stores
-- note text, keys, salts or codewords.
--
-- Access model: RLS on, NO policies. Only the service role (inside the
-- `canary` edge function) can read or write. Clients never query these tables.
--
-- Reverse (manual, if ever needed):
--   drop function if exists public.canary_assign_copy(uuid, text, text);
--   drop function if exists public.canary_lease_relayer(integer, integer);
--   drop function if exists public.canary_release_relayer(integer);
--   drop table if exists public.canary_copies;
--   drop table if exists public.canary_notes;
--   drop table if exists public.canary_relayer_leases;

create table if not exists public.canary_notes (
  id uuid primary key,
  owner_hash text not null check (owner_hash ~ '^[0-9a-f]{64}$'),
  copy_count integer not null check (copy_count between 2 and 100),
  copies_hash text not null check (copies_hash ~ '^0x[0-9a-f]{64}$'),
  chain_note_id text not null unique check (chain_note_id ~ '^0x[0-9a-f]{64}$'),
  seal_tx_hash text check (seal_tx_hash is null or seal_tx_hash ~ '^0x[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.canary_copies (
  note_id uuid not null references public.canary_notes(id) on delete cascade,
  copy_index integer not null check (copy_index >= 0 and copy_index < 100),
  ciphertext text not null check (char_length(ciphertext) <= 12000),
  iv text not null check (iv ~ '^[0-9a-f]{32}$'),
  reader_device_hash text check (reader_device_hash is null or reader_device_hash ~ '^[0-9a-f]{64}$'),
  reader_name text check (reader_name is null or char_length(reader_name) between 1 and 40),
  reader_tag text check (reader_tag is null or reader_tag ~ '^0x[0-9a-f]{64}$'),
  opened_at timestamptz,
  open_tx_hash text check (open_tx_hash is null or open_tx_hash ~ '^0x[0-9a-f]{64}$'),
  primary key (note_id, copy_index)
);

-- One copy per device per note (a retry gets the same copy back).
create unique index if not exists canary_copies_one_per_device
  on public.canary_copies (note_id, reader_device_hash)
  where reader_device_hash is not null;

-- One row per relayer key; a key is "leased" while it has a transaction in
-- flight, so no two requests ever use the same key (and nonce) at once.
create table if not exists public.canary_relayer_leases (
  relayer_index integer primary key check (relayer_index between 0 and 31),
  busy_until timestamptz not null default 'epoch'
);

alter table public.canary_notes enable row level security;
alter table public.canary_copies enable row level security;
alter table public.canary_relayer_leases enable row level security;

revoke all on public.canary_notes from anon, authenticated;
revoke all on public.canary_copies from anon, authenticated;
revoke all on public.canary_relayer_leases from anon, authenticated;
grant all on public.canary_notes to service_role;
grant all on public.canary_copies to service_role;
grant all on public.canary_relayer_leases to service_role;

-- Give a device its copy: the same copy again if it already has one,
-- otherwise the lowest unassigned copy. Concurrency-safe (SKIP LOCKED + the
-- unique index above). Returns no row when every copy is taken.
create or replace function public.canary_assign_copy(
  p_note_id uuid,
  p_device_hash text,
  p_reader_name text
)
returns table (
  copy_index integer,
  ciphertext text,
  iv text,
  reader_tag text,
  opened_at timestamptz,
  open_tx_hash text
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  return query
    select c.copy_index, c.ciphertext, c.iv, c.reader_tag, c.opened_at, c.open_tx_hash
      from public.canary_copies c
     where c.note_id = p_note_id
       and c.reader_device_hash = p_device_hash;
  if found then
    return;
  end if;

  return query
    update public.canary_copies c
       set reader_device_hash = p_device_hash,
           reader_name = p_reader_name,
           opened_at = now()
     where (c.note_id, c.copy_index) = (
             select c2.note_id, c2.copy_index
               from public.canary_copies c2
              where c2.note_id = p_note_id
                and c2.reader_device_hash is null
              order by c2.copy_index
              limit 1
              for update skip locked
           )
    returning c.copy_index, c.ciphertext, c.iv, c.reader_tag, c.opened_at, c.open_tx_hash;
end;
$$;

-- Lease a free relayer key index in [0, p_count). Null when all are busy.
create or replace function public.canary_lease_relayer(p_count integer, p_seconds integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_index integer;
begin
  insert into public.canary_relayer_leases (relayer_index)
  select g from generate_series(0, p_count - 1) as g
  on conflict (relayer_index) do nothing;

  select l.relayer_index into v_index
    from public.canary_relayer_leases l
   where l.relayer_index < p_count
     and l.busy_until < now()
   order by l.busy_until
   limit 1
   for update skip locked;

  if v_index is null then
    return null;
  end if;

  update public.canary_relayer_leases
     set busy_until = now() + make_interval(secs => p_seconds)
   where relayer_index = v_index;
  return v_index;
end;
$$;

create or replace function public.canary_release_relayer(p_index integer)
returns void
language sql
security definer
set search_path = public
as $$
  update public.canary_relayer_leases
     set busy_until = 'epoch'
   where relayer_index = p_index;
$$;

revoke all on function public.canary_assign_copy(uuid, text, text) from public, anon, authenticated;
revoke all on function public.canary_lease_relayer(integer, integer) from public, anon, authenticated;
revoke all on function public.canary_release_relayer(integer) from public, anon, authenticated;
grant execute on function public.canary_assign_copy(uuid, text, text) to service_role;
grant execute on function public.canary_lease_relayer(integer, integer) to service_role;
grant execute on function public.canary_release_relayer(integer) to service_role;
