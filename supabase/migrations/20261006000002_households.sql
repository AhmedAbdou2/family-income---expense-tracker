-- Phase 1 / Migration 2 of 10: households + household_users + helper functions
--
-- NOTE ON HELPER FUNCTIONS
--   household_role() and is_household_member() are SECURITY DEFINER so that
--   Row-Level-Status policies can query household_users WITHOUT causing
--   recursive policy evaluation (definer functions run as the table owner,
--   which is exempt from RLS). They are the ONLY membership oracle used by
--   the policies in migration 10.

create table if not exists public.households (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(trim(name)) between 1 and 80),
  currency   text not null default 'SAR' check (currency ~ '^[A-Z]{3}$'),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- No INSERT policy is ever granted on households (see migration 10).
-- Households are created exclusively through public.create_household().

create table if not exists public.household_users (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  role         text not null check (role in ('owner', 'adult', 'child')),
  created_at   timestamptz not null default now(),
  primary key (household_id, user_id)
);

-- Migration 10 of the plan: household_id index on EVERY table.
create index if not exists idx_household_users_household_id
  on public.household_users (household_id);
create index if not exists idx_household_users_user_id
  on public.household_users (user_id);

-- Returns the caller's role inside a household, or NULL when the caller is
-- not a member. Never exposes other users' rows to the caller directly.
create or replace function public.household_role(p_household_id uuid)
returns text
language sql
stable
security definer
set search_path = public
parallel safe
as $$
  select hu.role
  from public.household_users hu
  where hu.household_id = p_household_id
    and hu.user_id = auth.uid();
$$;

-- TRUE when the caller belongs to the household.
create or replace function public.is_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
parallel safe
as $$
  select exists (
    select 1
    from public.household_users hu
    where hu.household_id = p_household_id
      and hu.user_id = auth.uid()
  );
$$;
