-- Phase 2.5 / Migration 12: self-service membership (no pre-created person)
--
-- WHAT CHANGES
--   1. create_household(name, currency, display_name) - the owner's own
--      person row is created and linked at household creation.
--      Old 2-arg signature dropped first (see migration 11's note: the
--      old overload would keep resolving old calls otherwise).
--   2. accept_invite(code, display_name) - old 1-arg signature dropped.
--      Person-bound invite: explicit members.user_id IS NULL check that
--      raises 'already_linked' (distinct from create-time 'member_linked').
--      Join-only invite (member_id IS NULL): the joiner CHOOSES their own
--      name; a person row is created and linked in the same transaction.
--      Display name is REQUIRED on join-only invites (invalid_name).
--   3. claim_member(display_name) - for logins that already belong to a
--      household but have no person of their own (created before this
--      migration). Creates + links a person in every household the caller
--      belongs to that lacks one; raises member_linked when none is
--      missing. Takes no user/household argument: it can only ever touch
--      the caller's own rows.
--   4. rename_member(member_id, display_name) - the ONLY way to change a
--      person's name (see DIRECT-WRITE LOCKDOWN below). Owner: any person
--      of their household. Any other login: ONLY the person linked to
--      itself (children included).
--   5. update_household_role(household_id, user_id, role) - owner-only.
--      Promotion TO owner is allowed (ownership transfer path). A login
--      cannot change its own role; the last owner can never be demoted;
--      role 'child' requires the target login to have a linked person.
--   6. leave_household() - self-removal. Anyone may leave; the LAST owner
--      never can. Removes the membership and clears the link on the
--      caller's person; person rows and transactions are kept.
--   7. remove_household_login(household_id, user_id) - owner-only removal
--      of ANOTHER login. Self -> cannot_remove_self (use leave). Same
--      keep-transactions semantics.
--   8. members name trigger: trims and length-checks (1..40) person names
--      on INSERT and whenever the name changes. Defense in depth for the
--      remaining direct INSERT path (add-person).
--
-- CONCURRENCY (last-owner safety)
--   update_household_role / leave_household / remove_household_login all
--   take `SELECT ... FOR UPDATE` on the household's OWNER rows before
--   counting owners, so two simultaneous demotions/leaves serialize and
--   can never leave a household with zero owners.
--
-- DIRECT-WRITE LOCKDOWN
--   * household_users UPDATE policy from migration 10 is DROPPED:
--     roles can only change through update_household_role().
--   * members column grants: authenticated loses table-level UPDATE and
--     keeps only UPDATE(is_active). Names and links can no longer be
--     written directly; renames go through rename_member(), links only
--     through the definer flows (accept_invite / claim_member), which
--     bypass RLS as they always have.
--   * members INSERT WITH CHECK now also requires user_id IS NULL:
--     a direct insert can never attach a login to a person.
--   * members DELETE now only applies to UNLINKED persons.
--
-- ERROR KEYS RAISED (translated by the app's ExceptionMapper)
--   invalid_name            - empty / overlong name (any name entry point)
--   already_linked          - person-bound invite, person already claimed
--   member_linked           - claim_member called with nothing to claim
--   invalid_member          - target person/login not in caller's household
--   forbidden               - role/removal attempted by a non-owner
--   cannot_change_own_role  - a login editing its own role
--   cannot_remove_self      - remove_household_login targeting the caller
--   last_owner              - demoting/removing/leaving the only owner
--   child_requires_member   - setting role 'child' on an unlinked login
--   not_member              - claim_member without any household
--   not_authenticated       - signed-out caller
--
-- RLS IMPACT (plain language)
--   Roles and logins can no longer be edited straight at the table, even
--   by an owner's SQL client - only the new locked RPCs can. Person names
--   are enforced (trim + length) no matter which path writes them, and a
--   direct insert can't attach someone's login to a person anymore.
--   Everyone can still READ who is in the household (uuid/role/joined -
--   no emails). Transactions and person rows survive a login's removal.

-- ---------------------------------------------------------------------------
-- 1. create_household(name, currency, display_name) -> household id
-- ---------------------------------------------------------------------------
drop function if exists public.create_household(text, text);

create function public.create_household(
  p_name text,
  p_currency text default 'SAR',
  p_display_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid;
  v_name text := trim(coalesce(p_name, ''));
  v_currency text := upper(trim(coalesce(p_currency, '')));
  v_person text := btrim(coalesce(p_display_name, ''));
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if length(v_name) < 1 or length(v_name) > 80 then
    raise exception 'invalid_name';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'invalid_currency';
  end if;
  if length(v_person) < 1 or length(v_person) > 40 then
    raise exception 'invalid_name';
  end if;

  insert into public.households (name, currency, created_by)
  values (v_name, v_currency, v_user_id)
  returning id into v_household_id;

  insert into public.household_users (household_id, user_id, role)
  values (v_household_id, v_user_id, 'owner');

  -- The owner's own person, linked immediately: no orphan logins.
  insert into public.members (household_id, name, user_id)
  values (v_household_id, v_person, v_user_id);

  perform public.seed_default_categories(v_household_id);

  return v_household_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. accept_invite(code, display_name) -> household id
-- ---------------------------------------------------------------------------
drop function if exists public.accept_invite(text);

create function public.accept_invite(
  p_code text,
  p_display_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_invite record;
  v_user_id uuid := auth.uid();
  v_person text := btrim(coalesce(p_display_name, ''));
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select i.id, i.household_id, i.role, i.expires_at, i.used_by, i.member_id
    into v_invite
  from public.invites i
  where i.code = v_code
  for update;

  if not found then
    raise exception 'invite_not_found';
  end if;
  if v_invite.used_by is not null then
    raise exception 'invite_used';
  end if;
  if v_invite.expires_at is not null and v_invite.expires_at <= now() then
    raise exception 'invite_expired';
  end if;
  if exists (
    select 1 from public.household_users hu
    where hu.household_id = v_invite.household_id and hu.user_id = v_user_id
  ) then
    raise exception 'already_member';
  end if;

  if v_invite.member_id is not null then
    -- Person-bound invite: the joiner gets the person the owner picked;
    -- their own display_name is deliberately NOT used.
    if exists (
      select 1 from public.members m
      where m.household_id = v_invite.household_id and m.user_id = v_user_id
    ) then
      raise exception 'login_linked';
    end if;

    -- Explicit still-unlinked check (migration 11 did this implicitly
    -- through `and user_id is null` on the UPDATE). Distinct error key
    -- from create-time 'member_linked'.
    select m.user_id into v_person
      from public.members m
     where m.id = v_invite.member_id
       and m.household_id = v_invite.household_id;
    if not found then
      raise exception 'invalid_member';
    end if;
    if v_person is not null then
      raise exception 'already_linked';
    end if;

    update public.members
       set user_id = v_user_id
     where id = v_invite.member_id
       and household_id = v_invite.household_id
       and user_id is null;
    if not found then
      raise exception 'already_linked';
    end if;
  else
    -- Join-only invite: the joiner names themselves. Validated BEFORE any
    -- write, so a bad name never consumes the code.
    if length(v_person) < 1 or length(v_person) > 40 then
      raise exception 'invalid_name';
    end if;

    insert into public.members (household_id, name, user_id)
    values (v_invite.household_id, v_person, v_user_id);
  end if;

  insert into public.household_users (household_id, user_id, role)
  values (v_invite.household_id, v_user_id, v_invite.role);

  update public.invites
     set used_by = v_user_id
   where id = v_invite.id;

  return v_invite.household_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. claim_member(display_name) -> the created member id
--    For pre-existing logins that have a household but no person yet.
-- ---------------------------------------------------------------------------
create function public.claim_member(p_display_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_person text := btrim(coalesce(p_display_name, ''));
  v_household record;
  v_member_id uuid;
  v_created boolean := false;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if length(v_person) < 1 or length(v_person) > 40 then
    raise exception 'invalid_name';
  end if;
  if not exists (
    select 1 from public.household_users hu where hu.user_id = v_user_id
  ) then
    raise exception 'not_member';
  end if;

  -- Normally the caller is in exactly one household; if somehow in more,
  -- every household that lacks the caller's person gets one (same name).
  for v_household in
    select hu.household_id
      from public.household_users hu
     where hu.user_id = v_user_id
  loop
    if not exists (
      select 1 from public.members m
       where m.household_id = v_household.household_id
         and m.user_id = v_user_id
    ) then
      insert into public.members (household_id, name, user_id)
      values (v_household.household_id, v_person, v_user_id)
      returning id into v_member_id;
      v_created := true;
    end if;
  end loop;

  if not v_created then
    raise exception 'member_linked';
  end if;

  return v_member_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. rename_member(member_id, display_name)
-- ---------------------------------------------------------------------------
create function public.rename_member(
  p_member_id uuid,
  p_display_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_person text := btrim(coalesce(p_display_name, ''));
  v_member record;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if length(v_person) < 1 or length(v_person) > 40 then
    raise exception 'invalid_name';
  end if;

  select m.id, m.household_id, m.user_id into v_member
    from public.members m
   where m.id = p_member_id
     and exists (
       select 1 from public.household_users hu
        where hu.household_id = m.household_id and hu.user_id = v_user_id
     );
  if not found then
    raise exception 'invalid_member';
  end if;

  -- Owner may rename any person of the household; everyone else (adults
  -- and children alike) only the person linked to their own login.
  if public.household_role(v_member.household_id) = 'owner' then
    null;
  elsif v_member.user_id is distinct from v_user_id then
    raise exception 'forbidden';
  end if;

  update public.members
     set name = v_person
   where id = v_member.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. update_household_role(household_id, user_id, role)
-- ---------------------------------------------------------------------------
create function public.update_household_role(
  p_household_id uuid,
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_role text := lower(trim(coalesce(p_role, '')));
  v_target record;
  v_owner_count integer;
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;
  if public.household_role(p_household_id) <> 'owner' then
    raise exception 'forbidden';
  end if;
  if v_role not in ('owner', 'adult', 'child') then
    raise exception 'invalid_role';
  end if;

  -- Lock the owner rows BEFORE counting: two concurrent demotions or
  -- leaves serialize here and can never produce zero owners.
  perform 1 from public.household_users
   where household_id = p_household_id and role = 'owner'
     for update;

  select hu.user_id, hu.role into v_target
    from public.household_users hu
   where hu.household_id = p_household_id and hu.user_id = p_user_id;
  if not found then
    raise exception 'invalid_member';
  end if;

  select count(*) into v_owner_count
    from public.household_users
   where household_id = p_household_id and role = 'owner';

  -- Last-owner protection is checked BEFORE the self-check so the sole
  -- owner demoting themselves gets the more meaningful error.
  if v_target.role = 'owner' and v_role <> 'owner' and v_owner_count <= 1 then
    raise exception 'last_owner';
  end if;
  if p_user_id = v_caller then
    raise exception 'cannot_change_own_role';
  end if;
  if v_role = 'child' and not exists (
    select 1 from public.members m
     where m.household_id = p_household_id and m.user_id = p_user_id
  ) then
    raise exception 'child_requires_member';
  end if;

  update public.household_users
     set role = v_role
   where household_id = p_household_id and user_id = p_user_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. leave_household() - self-removal, keeps person + transactions
-- ---------------------------------------------------------------------------
create function public.leave_household()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_member record;
  v_owner_count integer;
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;

  select hu.household_id, hu.role into v_member
    from public.household_users hu
   where hu.user_id = v_caller;
  if not found then
    raise exception 'not_member';
  end if;

  -- Lock owners before counting (same serialization point as
  -- update_household_role / remove_household_login).
  perform 1 from public.household_users
   where household_id = v_member.household_id and role = 'owner'
     for update;

  if v_member.role = 'owner' then
    select count(*) into v_owner_count
      from public.household_users
     where household_id = v_member.household_id and role = 'owner';
    if v_owner_count <= 1 then
      raise exception 'last_owner';
    end if;
  end if;

  delete from public.household_users
   where household_id = v_member.household_id and user_id = v_caller;

  -- The person stays (transactions keep pointing at it) but becomes
  -- unlinked, so a future login can be linked to it again.
  update public.members
     set user_id = null
   where household_id = v_member.household_id and user_id = v_caller;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. remove_household_login(household_id, user_id) - owner removes other
-- ---------------------------------------------------------------------------
create function public.remove_household_login(
  p_household_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_target record;
  v_owner_count integer;
begin
  if v_caller is null then
    raise exception 'not_authenticated';
  end if;
  if public.household_role(p_household_id) <> 'owner' then
    raise exception 'forbidden';
  end if;

  perform 1 from public.household_users
   where household_id = p_household_id and role = 'owner'
     for update;

  select hu.user_id, hu.role into v_target
    from public.household_users hu
   where hu.household_id = p_household_id and hu.user_id = p_user_id;
  if not found then
    raise exception 'invalid_member';
  end if;

  if p_user_id = v_caller then
    raise exception 'cannot_remove_self';
  end if;

  if v_target.role = 'owner' then
    select count(*) into v_owner_count
      from public.household_users
     where household_id = p_household_id and role = 'owner';
    if v_owner_count <= 1 then
      raise exception 'last_owner';
    end if;
  end if;

  delete from public.household_users
   where household_id = p_household_id and user_id = p_user_id;

  update public.members
     set user_id = null
   where household_id = p_household_id and user_id = p_user_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Person-name validation trigger (trim + 1..40) on every write path
--    that reaches the table. RPCs validate first for consistent error
--    keys; this catches the direct INSERT path (add-person) and any
--    legacy caller. UPDATE is exempt while the name is unchanged so
--    is_active toggles / user_id linking never trip it.
-- ---------------------------------------------------------------------------
create or replace function public.members_validate_name()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_name text := btrim(coalesce(new.name, ''));
begin
  if tg_op = 'UPDATE' and new.name is not distinct from old.name then
    return new;
  end if;
  if length(v_name) < 1 or length(v_name) > 40 then
    raise exception 'invalid_name';
  end if;
  new.name := v_name;
  return new;
end;
$$;

drop trigger if exists trg_members_validate_name on public.members;
create trigger trg_members_validate_name
before insert or update on public.members
for each row execute function public.members_validate_name();

-- ---------------------------------------------------------------------------
-- 9. Policy changes
-- ---------------------------------------------------------------------------

-- Roles: no direct table path anymore -> update_household_role() only.
drop policy if exists "household_users_update_owner" on public.household_users;

-- Add-person: a direct insert can never attach a login to a person.
drop policy if exists "members_insert_adult" on public.members;
create policy "members_insert_adult" on public.members
  for insert to authenticated
  with check (
    public.is_household_member(household_id)
    and public.is_household_adult(household_id)
    and user_id is null
  );

-- Person deletion: only unlinked persons (a linked person's login would
-- silently lose its RLS anchor while still having transactions).
drop policy if exists "members_delete_adult" on public.members;
create policy "members_delete_adult" on public.members
  for delete to authenticated
  using (
    public.is_household_member(household_id)
    and public.is_household_adult(household_id)
    and user_id is null
  );

-- ---------------------------------------------------------------------------
-- 10. Column lockdown on members: names/links only via definer flows.
--     authenticated keeps direct UPDATE of is_active only (deactivate).
-- ---------------------------------------------------------------------------
revoke update on public.members from authenticated;
grant update (is_active) on public.members to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Privilege hardening (same sweep as migration 11, new names included)
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
         'vehicle_in_household', 'recurring_in_household')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;
