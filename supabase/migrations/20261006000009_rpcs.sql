-- Phase 1 / Migration 9 of 10: RPCs (the ONLY client entry points for
-- household creation and joining).
--
-- All three functions are SECURITY DEFINER so they can write
-- households / household_users / invites without any client-side INSERT
-- policy existing on those tables (see migration 10). Every function
-- validates the caller through auth.uid() itself - never trust parameters
-- for identity.
--
-- Error keys raised below are translated to localized messages by the app.

-- ---------------------------------------------------------------------------
-- create_household(name, currency) -> household id
-- Creates the household, adds the caller as owner and seeds the 31 default
-- bilingual categories, all in ONE transaction. Avoids the
-- "insert ... returning blocked by RLS" problem entirely.
-- ---------------------------------------------------------------------------
create or replace function public.create_household(
  p_name text,
  p_currency text default 'SAR'
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

  insert into public.households (name, currency, created_by)
  values (v_name, v_currency, v_user_id)
  returning id into v_household_id;

  insert into public.household_users (household_id, user_id, role)
  values (v_household_id, v_user_id, 'owner');

  perform public.seed_default_categories(v_household_id);

  return v_household_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- create_invite(household_id, role, ttl_days) -> 6-char code
-- Caller must be owner/adult of the target household. Codes are single use.
-- ---------------------------------------------------------------------------
create or replace function public.create_invite(
  p_household_id uuid,
  p_role text default 'child',
  p_ttl_days integer default 7
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_role text := lower(trim(coalesce(p_role, '')));
  v_ttl integer := coalesce(p_ttl_days, 7);
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

  loop
    -- 6 chars from the base64 alphabet, with + / = folded into letters so
    -- the result always matches ^[A-Z0-9]{6}$.
    v_code := upper(substr(
      encode(gen_random_bytes(9), 'base64'),
      1, 6
    ));
    v_code := translate(v_code, '+/=', 'XYZ');

    insert into public.invites (code, household_id, role, expires_at, created_by)
    values (v_code, p_household_id, v_role, now() + make_interval(days => v_ttl), auth.uid())
    on conflict (code) do nothing;

    exit when found;
  end loop;

  return v_code;
end;
$$;

-- ---------------------------------------------------------------------------
-- accept_invite(code) -> household id
-- The ONLY way to get a row into household_users besides create_household.
-- Single use: the code is consumed atomically on success.
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

  select i.id, i.household_id, i.role, i.expires_at, i.used_by
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

  insert into public.household_users (household_id, user_id, role)
  values (v_invite.household_id, v_user_id, v_invite.role);

  update public.invites
  set used_by = v_user_id
  where id = v_invite.id;

  return v_invite.household_id;
end;
$$;
