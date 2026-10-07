-- Phase 2 / Migration 11 of 11: member-bound invites (auto-link on accept)
--
-- WHAT CHANGES
--   1. invites gains an OPTIONAL member_id. When present, accepting the
--      code links the accepting login to that person:
--      members.user_id = auth.uid(). This is what gives a child login its
--      own person row (all child RLS policies hang off members.user_id).
--   2. create_invite() gains a 4th parameter p_member_id (default null).
--      The old 3-parameter function is dropped first, otherwise Postgres
--      would keep resolving 3-argument calls to the old overload.
--   3. accept_invite() performs the link INSIDE the same transaction as
--      the household_users insert: if linking fails, everything rolls
--      back and the code is not consumed.
--
-- INVARIANTS ENFORCED
--   - A member row can be bound to at most one invite acceptance:
--     members.user_id stays null until accept, then is set exactly once
--     (uq_members_household_user backs this per household).
--   - A login may be linked to at most ONE member per household; a
--     defensive check raises 'login_linked' before the unique index
--     could raise an opaque 23505.
--   - create_invite validates the member is in the SAME household and
--     still unlinked ('invalid_member' / 'member_linked').
--
-- INDEX FIX
--   Migration 3 created uq_members_household_user as
--   UNIQUE (household_id) WHERE user_id IS NOT NULL — at most ONE linked
--   member per household TOTAL, which made linking a second login (a child
--   person, a second parent) impossible. Replaced here with
--   UNIQUE (household_id, user_id) WHERE user_id IS NOT NULL: many people
--   per household may each be linked, but a given login can occupy only
--   one person row per household.
--
-- ERROR KEYS RAISED (translated by the app's ExceptionMapper)
--   invalid_member  - member_id missing or in another household
--   member_linked   - the person is already linked to a login
--   login_linked    - this login is already linked to a person here
--
-- RLS IMPACT: none. No policies change. invites still has no
-- INSERT/UPDATE/DELETE policy (RPC-only), and the members UPDATE inside
-- accept_invite runs as SECURITY DEFINER, so the owner/adult-only
-- members_update_adult policy is deliberately bypassed for this single,
-- validated path.

-- ---------------------------------------------------------------------------
-- 1. invites.member_id (optional person binding)
-- ---------------------------------------------------------------------------
alter table public.invites
  add column if not exists member_id uuid
  references public.members (id) on delete set null;

comment on column public.invites.member_id is
  'When set, accept_invite() links the accepting login to this person '
  '(members.user_id = auth.uid()).';

-- 1b. Replace migration 3's over-restrictive unique index (see INDEX FIX
--     in the header): UNIQUE (household_id) WHERE user_id IS NOT NULL
--     allowed only ONE linked person per household; the Phase-2 flow links
--     a different login to a different person (child, second parent).
drop index if exists public.uq_members_household_user;

create unique index if not exists uq_members_household_user
  on public.members (household_id, user_id) where user_id is not null;

-- ---------------------------------------------------------------------------
-- 2. create_invite(household_id, role, ttl_days, member_id) -> code
-- ---------------------------------------------------------------------------
drop function if exists public.create_invite(uuid, text, integer);

create function public.create_invite(
  p_household_id uuid,
  p_role text default 'child',
  p_ttl_days integer default 7,
  p_member_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
  v_role text := lower(trim(coalesce(p_role, '')));
  v_ttl integer := coalesce(p_ttl_days, 7);
  v_member record;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_household_member(p_household_id) then
    raise exception 'not_member';
  end if;
  if public.household_role(p_household_id) not in ('owner', 'adult') then
    raise exception 'forbidden';
  end if;
  if v_role not in ('adult', 'child') then
    raise exception 'invalid_role';
  end if;
  if v_ttl < 1 or v_ttl > 365 then
    raise exception 'invalid_ttl';
  end if;

  -- Optional person binding: must exist, live in THIS household, and
  -- still be unlinked to any login.
  if p_member_id is not null then
    select m.id, m.user_id into v_member
      from public.members m
     where m.id = p_member_id
       and m.household_id = p_household_id;
    if not found then
      raise exception 'invalid_member';
    end if;
    if v_member.user_id is not null then
      raise exception 'member_linked';
    end if;
  end if;

  loop
    -- 6 chars from the base64 alphabet, with + / = folded into letters so
    -- the result always matches ^[A-Z0-9]{6}$.
    v_code := upper(substr(
      encode(gen_random_bytes(9), 'base64'),
      1, 6
    ));
    v_code := translate(v_code, '+/=', 'XYZ');

    insert into public.invites
      (code, household_id, role, expires_at, created_by, member_id)
    values
      (v_code, p_household_id, v_role, now() + make_interval(days => v_ttl),
       auth.uid(), p_member_id)
    on conflict (code) do nothing;

    exit when found;
  end loop;

  return v_code;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. accept_invite(code) -> household id
--    Now ALSO links members.user_id when the code carries a member_id.
-- ---------------------------------------------------------------------------
create or replace function public.accept_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_invite record;
  v_user_id uuid := auth.uid();
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

  -- Person-bound invite: link this login to the invite's person.
  -- A failure here raises and rolls back the whole acceptance, so the
  -- code is never consumed and household_users is never written.
  if v_invite.member_id is not null then
    if exists (
      select 1 from public.members m
      where m.household_id = v_invite.household_id and m.user_id = v_user_id
    ) then
      raise exception 'login_linked';
    end if;

    update public.members
       set user_id = v_user_id
     where id = v_invite.member_id
       and household_id = v_invite.household_id
       and user_id is null;
    if not found then
      raise exception 'member_linked';
    end if;
  end if;

  insert into public.household_users (household_id, user_id, role)
  values (v_invite.household_id, v_user_id, v_invite.role);

  update public.invites
  set used_by = v_user_id
  where id = v_invite.id;

  return v_invite.household_id;
end;
$$;

-- 4. Privilege hardening for SECURITY DEFINER functions.
--    CREATE FUNCTION grants EXECUTE to PUBLIC by default, so migrations 9/10
--    left every definer helper/RPC executable by anon even though only
--    seed_default_categories was explicitly revoked. Dropping + recreating
--    create_invite also gave it a fresh OID whose authenticated grant was
--    lost. This sweep:
--      - revokes EXECUTE from public + anon on every definer function in
--        schema public (ours and any Supabase-provided helpers);
--      - (re)grants EXECUTE ONLY to `authenticated` for the known RPC/helper
--        set the app and RLS policies actually need;
--      - keeps the trigger function and seed_default_categories executable
--        by nobody.
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
         'household_role', 'is_household_member', 'is_household_adult',
         'owns_member_row', 'member_in_household', 'category_in_household',
         'vehicle_in_household', 'recurring_in_household')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;
