-- NO SUS Canary: Solana devnet proof. Experiment project ffidvfguojalzpclipzi ONLY.
-- Never apply to production (rxfnazmusofikwaggntb).
--
-- Adds the Solana memo signature next to each Monad transaction hash. Like the
-- Monad hashes these are public identifiers of sha256-based ids; the server
-- still never stores note text, keys, salts or codewords.
--
-- Apply before deploying the `canary` edge function that selects these columns.
--
-- Reverse (manual, if ever needed):
--   drop function if exists public.canary_assign_copy(uuid, text, text);
--   alter table public.canary_copies drop column if exists open_solana_sig;
--   alter table public.canary_notes drop column if exists seal_solana_sig;
--   -- then re-create canary_assign_copy and its grants from 20260919090000_nosus_canary.sql

alter table public.canary_notes
  add column if not exists seal_solana_sig text
    check (seal_solana_sig is null or seal_solana_sig ~ '^[1-9A-HJ-NP-Za-km-z]{64,100}$');

alter table public.canary_copies
  add column if not exists open_solana_sig text
    check (open_solana_sig is null or open_solana_sig ~ '^[1-9A-HJ-NP-Za-km-z]{64,100}$');

-- Same function as before plus open_solana_sig in the result. Postgres cannot
-- change a function's result columns with "or replace", so drop it first; the
-- grants are dropped with it and re-applied below.
drop function if exists public.canary_assign_copy(uuid, text, text);

-- Give a device its copy: the same copy again if it already has one,
-- otherwise the lowest unassigned copy. Concurrency-safe (SKIP LOCKED + the
-- one-per-device unique index). Returns no row when every copy is taken.
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
  open_tx_hash text,
  open_solana_sig text
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  return query
    select c.copy_index, c.ciphertext, c.iv, c.reader_tag, c.opened_at, c.open_tx_hash, c.open_solana_sig
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
    returning c.copy_index, c.ciphertext, c.iv, c.reader_tag, c.opened_at, c.open_tx_hash, c.open_solana_sig;
end;
$$;

revoke all on function public.canary_assign_copy(uuid, text, text) from public, anon, authenticated;
grant execute on function public.canary_assign_copy(uuid, text, text) to service_role;
