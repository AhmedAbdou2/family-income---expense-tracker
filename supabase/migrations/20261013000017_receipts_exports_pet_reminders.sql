-- ===================================================================
-- 17. Phase 4b: transaction receipts, pet reminders (+ receipt-aware
--     transaction deletion)
-- ===================================================================
-- WHAT CHANGES
--   1. NEW `transaction_receipts`: at most 3 receipt attachments per
--      transaction (a receipt metadata row per file). The file bytes live
--      in the private Storage bucket `receipts`, under the path
--      `<household_id>/<transaction_id>/<uuid>.<ext>`; only the path is
--      stored here. A trigger re-checks the path shape, the mime allow
--      list, the 5 MiB cap and the 3-per-transaction limit on every
--      insert (defense in depth behind the RPCs).
--   2. NEW `pet_reminders`: vaccine / vet-visit / other reminders with a
--      due date and an optional "repeat every N months". Completing one
--      may post a pet expense and, when it repeats, inserts the next one.
--   3. Storage: the `receipts` bucket is created PRIVATE with a 5 MiB
--      file size limit and an image/PDF mime allow list (real server-side
--      enforcement by the Storage service). Three policies on
--      `storage.objects` scope every touch to an owner/adult of the
--      household named in the path's FIRST folder.
--   4. Receipt RPCs: request_receipt_upload / attach_receipt /
--      delete_receipt / list_orphan_receipts.
--   5. Transaction deletion moves behind `delete_transaction`, and
--      delete_fuel_log / archive_recurring_rule now RETURN the storage
--      paths of every receipt they cascade away, so the app can remove
--      the storage objects too (no orphans).
--   6. Pet-reminder RPCs: create / update / complete / delete.
--
-- WHY THE OBJECT PATH IS `household_id/transaction_id/...`
--   Storage policies can only look at the object name, so the household
--   id has to be IN the path. `request_receipt_upload` mints the path
--   server-side from the transaction row (the client never chooses it),
--   and `attach_receipt` re-validates it: a user can neither guess nor
--   craft a path that policy would accept for another household.
--
-- AMENDMENT A - deleting objects after the transaction is gone
--   The DELETE policy checks ONLY the household folder (adult of folder
--   #1 + the expected path shape), NOT that the transaction still exists:
--   once `delete_transaction` removed the row, the client must still be
--   able to delete that transaction's objects.
--   SELECT is scoped the SAME WAY, and this is not optional: PostgreSQL
--   only lets a DELETE touch rows that are VISIBLE under the SELECT
--   policy, so a transaction-scoped SELECT policy made orphaned receipts
--   undeletable (verified in Docker). INSERT keeps the stricter,
--   transaction-scoped check because a client must never be able to
--   attach an object to a transaction that does not exist.
--   `list_orphan_receipts` (the sweep for objects whose row is gone) is
--   scoped the same way as DELETE.
--
-- AMENDMENT C - do not trust the client's mime/size
--   `attach_receipt` requires the object to really exist in
--   `storage.objects` (bucket `receipts`, exact path) and, when the stored
--   metadata carries them, takes the mime type and the size FROM THE
--   STORED OBJECT, then re-validates them. If the Storage service did not
--   record a value, the client-declared value is validated instead.
--
-- ERROR KEYS RAISED (translated by the app's ExceptionMapper)
--   not_authenticated   - no session
--   forbidden           - caller is not an owner/adult (or, for
--                         delete_transaction, not allowed to delete that
--                         row under the transactions_delete rule)
--   invalid_transaction - unknown transaction id
--   invalid_receipt     - unknown receipt id, or the object is missing
--                         from storage / the path has the wrong shape
--   invalid_mime        - mime type outside the image/PDF allow list
--   limit_reached       - a 4th receipt on the same transaction
--   invalid_value       - size <= 0, size > 5 MiB, bad expense amount
--   invalid_pet         - pet id unknown (a foreign household's pet is
--                         `forbidden`, like every other *-in-household RPC)
--   invalid_reminder    - reminder id unknown / invisible
--   no_pet_category     - no pet-group category to attach the expense
--   no_linked_person    - caller (adult) has no person of their own
--
-- RLS IMPACT (plain language)
--   * transaction_receipts: owner/adult can READ their household's
--     receipts; NOBODY can write the table directly (INSERT/UPDATE/DELETE
--     revoked) - the RPCs are the only path. A child sees ZERO rows and
--     every receipt RPC says `forbidden`.
--   * pet_reminders: owner/adult only, RPC-only writes.
--   * storage.objects (bucket `receipts` only): an owner/adult of the
--     household in the path may select, insert and delete objects under
--     it; a child, a foreign household and `anon` see nothing and can
--     neither upload nor delete. Nothing else changes; the receipts live
--     in a PRIVATE bucket, so only short-lived signed URLs can read them.
--   * Deleting a transaction still follows the SAME rule as before
--     (owner/adult: any row of the household; child: only their own
--     person's rows) - now enforced in `delete_transaction`.
-- ===================================================================

-- ---------------------------------------------------------------------------
-- 1. transaction_receipts
-- ---------------------------------------------------------------------------
create table if not exists public.transaction_receipts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  storage_path text not null,
  mime text not null check (mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  size_bytes integer not null check (size_bytes > 0 and size_bytes <= 5242880),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create unique index if not exists transaction_receipts_path_uniq
  on public.transaction_receipts (storage_path);
create index if not exists idx_transaction_receipts_household_id
  on public.transaction_receipts (household_id);
create index if not exists idx_transaction_receipts_transaction_id
  on public.transaction_receipts (transaction_id);

comment on table public.transaction_receipts is
  'Receipt attachments for a transaction (max 3). The bytes live in the '
  'private storage bucket `receipts`; only the object path is kept here.';

-- Defense in depth: the path must be household_id/transaction_id/<file>,
-- the mime/size must be inside the allow list, and a transaction may hold
-- at most 3 receipts no matter which write path is used.
create or replace function public.transaction_receipts_validate()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_count integer;
begin
  if split_part(new.storage_path, '/', 1) <> new.household_id::text
     or split_part(new.storage_path, '/', 2) <> new.transaction_id::text
     or split_part(new.storage_path, '/', 3) = '' then
    raise exception 'invalid_receipt';
  end if;

  if new.mime is null
     or new.mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then
    raise exception 'invalid_mime';
  end if;

  if new.size_bytes is null or new.size_bytes <= 0 then
    raise exception 'invalid_value';
  end if;
  if new.size_bytes > 5242880 then
    raise exception 'invalid_value';
  end if;

  select count(*) into v_count
    from public.transaction_receipts r
   where r.transaction_id = new.transaction_id;
  if v_count >= 3 then
    raise exception 'limit_reached';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_transaction_receipts_validate on public.transaction_receipts;
create trigger trg_transaction_receipts_validate
before insert on public.transaction_receipts
for each row execute function public.transaction_receipts_validate();

-- ---------------------------------------------------------------------------
-- 2. pet_reminders
-- ---------------------------------------------------------------------------
create table if not exists public.pet_reminders (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  pet_id uuid not null references public.pets(id) on delete cascade,
  title text not null,
  kind text not null check (kind in ('vaccine', 'vet', 'other')),
  due_date date not null,
  repeat_months integer check (repeat_months is null or (repeat_months >= 1 and repeat_months <= 120)),
  done_at timestamptz,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index if not exists idx_pet_reminders_household_id
  on public.pet_reminders (household_id);
create index if not exists idx_pet_reminders_pet_due
  on public.pet_reminders (pet_id, due_date);

create or replace function public.pet_reminders_validate_title()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_title text := btrim(coalesce(new.title, ''));
begin
  if tg_op = 'UPDATE' and new.title is not distinct from old.title then
    return new;
  end if;
  if length(v_title) < 1 or length(v_title) > 60 then
    raise exception 'invalid_name';
  end if;
  new.title := v_title;
  return new;
end;
$$;

drop trigger if exists trg_pet_reminders_validate_title on public.pet_reminders;
create trigger trg_pet_reminders_validate_title
before insert or update on public.pet_reminders
for each row execute function public.pet_reminders_validate_title();

-- ---------------------------------------------------------------------------
-- 3. Storage: private bucket + path helpers + policies
-- ---------------------------------------------------------------------------
-- Everything here is skipped (with a notice) on a database that has no
-- `storage` schema, so the migration still runs on a bare Postgres. The
-- cloud Supabase always has it.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    -- 3a. Private bucket with real server-side type/size enforcement.
    execute $sql$
      insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
      values ('receipts', 'receipts', false, 5242880,
              array['image/jpeg','image/png','image/webp','application/pdf'])
      on conflict (id) do update
        set public = false,
            file_size_limit = 5242880,
            allowed_mime_types = array['image/jpeg','image/png','image/webp','application/pdf']
    $sql$;
  else
    raise notice 'no storage schema: skipping receipts bucket + storage policies';
  end if;
end $$;

-- 3b. Path helpers. Storage policies can only inspect the object name, so
-- these read the household id out of folder #1 and - for the paths that run
-- while the transaction is alive - confirm folder #2 is a live transaction
-- of that household.
create or replace function public.receipt_path_adult(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, storage
as $$
declare
  v_parts text[];
  v_household uuid;
begin
  if p_name is null then
    return false;
  end if;
  v_parts := storage.foldername(p_name);
  if v_parts is null or array_length(v_parts, 1) < 2 then
    return false;
  end if;
  -- Guard the cast: a crafted name must never raise, only be rejected.
  if v_parts[1] !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return false;
  end if;
  v_household := v_parts[1]::uuid;

  if public.is_household_adult(v_household) is not true then
    return false;
  end if;

  return exists (
    select 1
      from public.transactions t
     where t.household_id = v_household
       and t.id::text = v_parts[2]
  );
end;
$$;

-- Amendment A: DELETE (and the read-back the client needs to sweep) must
-- NOT require the transaction to still exist - only the household folder
-- and the shape.
--
-- WHY THE SELECT POLICY USES THIS TOO (verified in Docker): PostgreSQL
-- only lets a DELETE touch rows that are VISIBLE under the table's SELECT
-- policy, even when the DELETE policy's own USING clause is satisfied. A
-- transaction-scoped SELECT policy would therefore make a deleted
-- transaction's receipts undeletable - exactly the leak amendment A
-- forbids. So SELECT + DELETE are household-scoped, while INSERT stays
-- transaction-scoped (a client can never attach an object to a
-- transaction that does not exist).
create or replace function public.receipt_path_household_adult(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, storage
as $$
declare
  v_parts text[];
  v_household uuid;
begin
  if p_name is null then
    return false;
  end if;
  v_parts := storage.foldername(p_name);
  if v_parts is null or array_length(v_parts, 1) < 2 then
    return false;
  end if;
  if v_parts[1] !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return false;
  end if;
  v_household := v_parts[1]::uuid;

  return public.is_household_adult(v_household) is true;
end;
$$;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage')
     and to_regclass('storage.objects') is not null then
    execute 'drop policy if exists "receipts_select_adult" on storage.objects';
    execute 'drop policy if exists "receipts_insert_adult" on storage.objects';
    execute 'drop policy if exists "receipts_delete_adult" on storage.objects';

    execute $sql$
      create policy "receipts_select_adult" on storage.objects
        for select to authenticated
        using (bucket_id = 'receipts' and public.receipt_path_household_adult(name))
    $sql$;

    execute $sql$
      create policy "receipts_insert_adult" on storage.objects
        for insert to authenticated
        with check (bucket_id = 'receipts' and public.receipt_path_adult(name))
    $sql$;

    -- No transaction check here on purpose (see AMENDMENT A above).
    execute $sql$
      create policy "receipts_delete_adult" on storage.objects
        for delete to authenticated
        using (bucket_id = 'receipts' and public.receipt_path_household_adult(name))
    $sql$;

    raise notice 'receipts bucket + storage policies installed';
  else
    raise notice 'no storage.objects: skipping receipt storage policies';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4a. request_receipt_upload(): mint the ONE path the client may upload to
-- ---------------------------------------------------------------------------
-- The path is derived from the transaction row, so the client cannot pick a
-- path (and therefore cannot target another household). Nothing is written
-- yet: the object is uploaded, then attach_receipt records it.
create or replace function public.request_receipt_upload(
  p_transaction_id uuid,
  p_mime text,
  p_size integer
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tx record;
  v_count integer;
  v_ext text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select t.id, t.household_id into v_tx
    from public.transactions t
   where t.id = p_transaction_id;
  if not found then
    raise exception 'invalid_transaction';
  end if;
  if public.is_household_adult(v_tx.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if p_mime is null
     or p_mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then
    raise exception 'invalid_mime';
  end if;
  if p_size is null or p_size <= 0 or p_size > 5242880 then
    raise exception 'invalid_value';
  end if;

  select count(*) into v_count
    from public.transaction_receipts r
   where r.transaction_id = p_transaction_id;
  if v_count >= 3 then
    raise exception 'limit_reached';
  end if;

  v_ext := case p_mime
             when 'image/jpeg' then 'jpg'
             when 'image/png' then 'png'
             when 'image/webp' then 'webp'
             else 'pdf'
           end;

  return v_tx.household_id::text || '/' || v_tx.id::text || '/' ||
         gen_random_uuid()::text || '.' || v_ext;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4b. attach_receipt(): record the uploaded object (AMENDMENT C)
-- ---------------------------------------------------------------------------
create or replace function public.attach_receipt(
  p_transaction_id uuid,
  p_path text,
  p_mime text,
  p_size integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tx record;
  v_count integer;
  v_mime text := p_mime;
  v_size integer := p_size;
  v_meta jsonb;
  v_found boolean := false;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select t.id, t.household_id into v_tx
    from public.transactions t
   where t.id = p_transaction_id;
  if not found then
    raise exception 'invalid_transaction';
  end if;
  if public.is_household_adult(v_tx.household_id) is not true then
    raise exception 'forbidden';
  end if;

  -- The path must be exactly the one request_receipt_upload would mint.
  if p_path is null
     or split_part(p_path, '/', 1) <> v_tx.household_id::text
     or split_part(p_path, '/', 2) <> v_tx.id::text
     or split_part(p_path, '/', 3) = '' then
    raise exception 'invalid_receipt';
  end if;

  -- The object must REALLY exist. Take mime/size from the stored object
  -- when Storage recorded them (dynamic SQL so a bare database without the
  -- storage schema still creates this function).
  if to_regclass('storage.objects') is not null then
    -- NOTE: EXECUTE does not set FOUND, so ask for existence explicitly.
    execute 'select exists (select 1 from storage.objects o where o.bucket_id = $1 and o.name = $2)'
      into v_found using 'receipts', p_path;
    if v_found is not true then
      raise exception 'invalid_receipt';
    end if;
    execute 'select o.metadata from storage.objects o where o.bucket_id = $1 and o.name = $2'
      into v_meta using 'receipts', p_path;
    if v_meta is not null and v_meta ? 'mimetype' then
      v_mime := v_meta ->> 'mimetype';
    end if;
    if v_meta is not null and v_meta ? 'size' then
      v_size := (v_meta ->> 'size')::integer;
    end if;
  end if;

  -- Three per transaction is the cap. Checked last so the error a client
  -- sees for a genuinely missing object is invalid_receipt, not the cap.
  select count(*) into v_count
    from public.transaction_receipts r
   where r.transaction_id = p_transaction_id;
  if v_count >= 3 then
    raise exception 'limit_reached';
  end if;

  if v_mime is null
     or v_mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then
    raise exception 'invalid_mime';
  end if;
  if v_size is null or v_size <= 0 or v_size > 5242880 then
    raise exception 'invalid_value';
  end if;

  insert into public.transaction_receipts
    (household_id, transaction_id, storage_path, mime, size_bytes, created_by)
  values
    (v_tx.household_id, v_tx.id, p_path, v_mime, v_size, auth.uid())
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4c. delete_receipt(): drop the row, hand the path back for object removal
-- ---------------------------------------------------------------------------
create or replace function public.delete_receipt(p_receipt_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receipt record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select r.household_id, r.storage_path into v_receipt
    from public.transaction_receipts r
   where r.id = p_receipt_id;
  if not found then
    raise exception 'invalid_receipt';
  end if;
  if public.is_household_adult(v_receipt.household_id) is not true then
    raise exception 'forbidden';
  end if;

  delete from public.transaction_receipts where id = p_receipt_id;
  return v_receipt.storage_path;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4d. list_orphan_receipts(): objects under MY household(s) with no row
-- ---------------------------------------------------------------------------
-- Runs as the caller's adult households only. Used as a sweep so a failed
-- object-removal (network drop between the delete RPC and the storage
-- delete) still self-heals.
create or replace function public.list_orphan_receipts()
returns setof text
language plpgsql
stable
security definer
set search_path = public, storage
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if to_regclass('storage.objects') is null then
    return;
  end if;

  return query execute $q$
    select o.name
      from storage.objects o
     where o.bucket_id = 'receipts'
       and array_length(storage.foldername(o.name), 1) >= 2
       and public.receipt_path_household_adult(o.name)
       and not exists (
         select 1 from public.transaction_receipts r
          where r.storage_path = o.name
       )
  $q$;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5a. delete_transaction(): same delete rule as before + returns paths
-- ---------------------------------------------------------------------------
-- Mirrors the transactions_delete policy exactly:
--   owner/adult -> any transaction of their household;
--   child       -> only transactions of the person linked to their login;
--   anyone else -> forbidden.
create or replace function public.delete_transaction(p_transaction_id uuid)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tx record;
  v_paths text[];
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select t.id, t.household_id, t.member_id into v_tx
    from public.transactions t
   where t.id = p_transaction_id;
  if not found then
    raise exception 'invalid_transaction';
  end if;

  if public.is_household_member(v_tx.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if public.is_household_adult(v_tx.household_id) is not true
     and public.owns_member_row(v_tx.household_id, v_tx.member_id) is not true then
    raise exception 'forbidden';
  end if;

  select coalesce(array_agg(r.storage_path order by r.created_at), array[]::text[])
    into v_paths
    from public.transaction_receipts r
   where r.transaction_id = p_transaction_id;

  -- Receipt rows cascade away with the transaction.
  delete from public.transactions where id = p_transaction_id;

  return v_paths;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5b. delete_fuel_log(): recreate so it also returns the receipt paths
-- ---------------------------------------------------------------------------
drop function if exists public.delete_fuel_log(uuid);

create function public.delete_fuel_log(p_log_id uuid)
returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_log record;
  v_paths text[] := array[]::text[];
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select fl.household_id, fl.transaction_id into v_log
    from public.fuel_logs fl
   where fl.id = p_log_id;
  if not found then
    raise exception 'invalid_log';
  end if;
  if public.is_household_adult(v_log.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if v_log.transaction_id is not null then
    select coalesce(array_agg(r.storage_path order by r.created_at), array[]::text[])
      into v_paths
      from public.transaction_receipts r
     where r.transaction_id = v_log.transaction_id;
    delete from public.transactions where id = v_log.transaction_id;
  end if;
  delete from public.fuel_logs where id = p_log_id;

  return v_paths;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5c. archive_recurring_rule(): recreate so it also returns receipt paths
-- ---------------------------------------------------------------------------
drop function if exists public.archive_recurring_rule(uuid, boolean);

create function public.archive_recurring_rule(
  p_rule_id uuid,
  p_delete_month_transactions boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_rule record;
  v_deleted integer := 0;
  v_paths text[] := array[]::text[];
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select r.id, r.household_id, r.archived_at
    into v_rule
    from public.recurring_rules r
   where r.id = p_rule_id
   for update;

  if not found then
    raise exception 'invalid_rule';
  end if;

  if public.is_household_adult(v_rule.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if v_rule.archived_at is not null then
    raise exception 'already_archived';
  end if;

  if p_delete_month_transactions then
    with deleted as (
      delete from public.transactions t
       where t.recurring_rule_id = p_rule_id
         and t.household_id = v_rule.household_id
         and t.date >= date_trunc('month', current_date)::date
         and t.date < (date_trunc('month', current_date) + interval '1 month')::date
      returning t.id
    )
    select coalesce(array_agg(r.storage_path order by r.created_at), array[]::text[]),
           (select count(*) from deleted)::integer
      into v_paths, v_deleted
      from public.transaction_receipts r
     where r.transaction_id in (select id from deleted);
  end if;

  update public.recurring_rules
     set is_active = false,
         archived_at = now()
   where id = p_rule_id;

  return jsonb_build_object('deleted', v_deleted, 'receipt_paths', to_jsonb(v_paths));
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Pet-reminder RPCs
-- ---------------------------------------------------------------------------
create or replace function public.create_pet_reminder(
  p_pet_id uuid,
  p_title text,
  p_kind text,
  p_due_date date,
  p_repeat_months integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pet record;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select p.id, p.household_id into v_pet
    from public.pets p
   where p.id = p_pet_id;
  if not found then
    raise exception 'invalid_pet';
  end if;
  if public.is_household_adult(v_pet.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if p_kind is null or p_kind not in ('vaccine', 'vet', 'other') then
    raise exception 'invalid_value';
  end if;
  if p_due_date is null then
    raise exception 'invalid_value';
  end if;
  if p_repeat_months is not null and (p_repeat_months < 1 or p_repeat_months > 120) then
    raise exception 'invalid_value';
  end if;

  insert into public.pet_reminders
    (household_id, pet_id, title, kind, due_date, repeat_months, created_by)
  values
    (v_pet.household_id, v_pet.id, btrim(coalesce(p_title, '')), p_kind,
     p_due_date, p_repeat_months, auth.uid())
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_pet_reminder(
  p_reminder_id uuid,
  p_title text,
  p_kind text,
  p_due_date date,
  p_repeat_months integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rem record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select r.id, r.household_id into v_rem
    from public.pet_reminders r
   where r.id = p_reminder_id;
  if not found then
    raise exception 'invalid_reminder';
  end if;
  if public.is_household_adult(v_rem.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if p_kind is null or p_kind not in ('vaccine', 'vet', 'other') then
    raise exception 'invalid_value';
  end if;
  if p_due_date is null then
    raise exception 'invalid_value';
  end if;
  if p_repeat_months is not null and (p_repeat_months < 1 or p_repeat_months > 120) then
    raise exception 'invalid_value';
  end if;

  update public.pet_reminders
     set title = btrim(coalesce(p_title, '')),
         kind = p_kind,
         due_date = p_due_date,
         repeat_months = p_repeat_months
   where id = p_reminder_id;
end;
$$;

-- Resolve a pet-group category for the optional expense: 'Vaccines' for a
-- vaccine, 'Vet' otherwise, else any pet-group category, else fail loudly.
create or replace function public.pet_category_for(p_household_id uuid, p_kind text)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_category uuid;
  v_wanted text := case when p_kind = 'vaccine' then 'Vaccines' else 'Vet' end;
begin
  select c.id into v_category
    from public.categories c
   where c.household_id = p_household_id and c."group" = 'pet'
   order by (c.name_en = v_wanted) desc, (c.name_en = 'Vet') desc, c.created_at asc
   limit 1;
  return v_category;
end;
$$;

create or replace function public.complete_pet_reminder(
  p_reminder_id uuid,
  p_amount_minor integer default null,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rem record;
  v_category uuid;
  v_member uuid;
  v_cost numeric(12,2);
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select r.id, r.household_id, r.pet_id, r.title, r.kind, r.due_date,
         r.repeat_months
    into v_rem
    from public.pet_reminders r
   where r.id = p_reminder_id
   for update;
  if not found then
    raise exception 'invalid_reminder';
  end if;
  if public.is_household_adult(v_rem.household_id) is not true then
    raise exception 'forbidden';
  end if;

  update public.pet_reminders
     set done_at = now()
   where id = p_reminder_id;

  -- A repeating reminder keeps its history and schedules the next one.
  if v_rem.repeat_months is not null then
    insert into public.pet_reminders
      (household_id, pet_id, title, kind, due_date, repeat_months, created_by)
    values
      (v_rem.household_id, v_rem.pet_id, v_rem.title, v_rem.kind,
       (v_rem.due_date + (v_rem.repeat_months || ' months')::interval)::date,
       v_rem.repeat_months, auth.uid());
  end if;

  if p_amount_minor is not null then
    if p_amount_minor <= 0 then
      raise exception 'invalid_value';
    end if;

    v_category := public.pet_category_for(v_rem.household_id, v_rem.kind);
    if v_category is null then
      raise exception 'no_pet_category';
    end if;

    select m.id into v_member
      from public.members m
     where m.household_id = v_rem.household_id
       and m.user_id = auth.uid()
       and m.is_active
     limit 1;
    if v_member is null then
      raise exception 'no_linked_person';
    end if;

    v_cost := p_amount_minor::numeric / 100;

    insert into public.transactions
      (household_id, type, amount, category_id, member_id, pet_id, date, note)
    values
      (v_rem.household_id, 'expense', v_cost, v_category, v_member,
       v_rem.pet_id, current_date,
       coalesce(nullif(btrim(coalesce(p_note, '')), ''), v_rem.title));
  end if;
end;
$$;

create or replace function public.delete_pet_reminder(p_reminder_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rem record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select r.id, r.household_id into v_rem
    from public.pet_reminders r
   where r.id = p_reminder_id;
  if not found then
    raise exception 'invalid_reminder';
  end if;
  if public.is_household_adult(v_rem.household_id) is not true then
    raise exception 'forbidden';
  end if;

  delete from public.pet_reminders where id = p_reminder_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. RLS: receipts + pet reminders are adult-only, writes are RPC-only
-- ---------------------------------------------------------------------------
alter table public.transaction_receipts enable row level security;
alter table public.pet_reminders enable row level security;

drop policy if exists "transaction_receipts_select_adult" on public.transaction_receipts;
-- "Only owners and adults can see the household's receipts at all."
create policy "transaction_receipts_select_adult" on public.transaction_receipts
  for select to authenticated
  using (public.is_household_adult(household_id));

drop policy if exists "pet_reminders_select_adult" on public.pet_reminders;
create policy "pet_reminders_select_adult" on public.pet_reminders
  for select to authenticated
  using (public.is_household_adult(household_id));

-- No INSERT / UPDATE / DELETE policies on either table -> the RPCs are the
-- only write path.
grant select on public.transaction_receipts, public.pet_reminders
  to authenticated, service_role;
revoke insert, update, delete on public.transaction_receipts from authenticated, anon;
revoke insert, update, delete on public.pet_reminders from authenticated, anon;

-- ---------------------------------------------------------------------------
-- 8. Privilege hardening (same sweep as migrations 11-16)
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure::text as proc
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prosecdef
  loop
    execute format('revoke execute on function %s from public, anon;', r.proc);
  end loop;

  for r in
    select p.oid::regprocedure::text as proc
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prosecdef
       and not exists (select 1 from pg_trigger t where t.tgfoid = p.oid)
       and p.proname in (
         'create_household', 'create_invite', 'accept_invite',
         'claim_member', 'rename_member', 'update_household_role',
         'leave_household', 'remove_household_login',
         'household_role', 'is_household_member', 'is_household_adult',
         'owns_member_row', 'member_in_household', 'category_in_household',
         'vehicle_in_household', 'recurring_in_household', 'pet_in_household',
         'add_fuel_log', 'delete_fuel_log', 'complete_maintenance',
         'generate_recurring_transactions', 'archive_recurring_rule',
         'set_category_budget', 'set_overall_budget', 'set_budget_active',
         'delete_budget', 'monthly_totals',
         'receipt_path_adult', 'receipt_path_household_adult',
         'request_receipt_upload', 'attach_receipt', 'delete_receipt',
         'list_orphan_receipts', 'delete_transaction',
         'pet_category_for', 'create_pet_reminder', 'update_pet_reminder',
         'complete_pet_reminder', 'delete_pet_reminder')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;
