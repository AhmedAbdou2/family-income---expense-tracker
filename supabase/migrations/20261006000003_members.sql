-- Phase 1 / Migration 3 of 10: members
--
-- members = the PEOPLE whose spending is tracked inside a household.
-- members.user_id (nullable) links a member to a Supabase Auth login.
-- Child-role RLS policies are based on that link (NOT on member_id guesses),
-- so a child only ever sees/creates transactions for rows where
-- members.user_id = auth.uid().

create table if not exists public.members (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name         text not null check (length(trim(name)) between 1 and 60),
  avatar       text,
  is_active    boolean not null default true,
  user_id      uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now()
);

-- A login may be linked to at most ONE member per household.
create unique index if not exists uq_members_household_user
  on public.members (household_id) where user_id is not null;

create index if not exists idx_members_household_id
  on public.members (household_id);

create index if not exists idx_members_user_id
  on public.members (user_id) where user_id is not null;
