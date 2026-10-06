-- Phase 1 / Migration 8 of 10: invites
--
-- Joining a household is ONLY possible through public.accept_invite(code).
-- There is deliberately NO INSERT policy on household_users or invites:
-- a user can never place themselves into an arbitrary household.

create table if not exists public.invites (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  household_id uuid not null references public.households (id) on delete cascade,
  -- 'owner' can never be invited: ownership is transferred explicitly later.
  role         text not null check (role in ('adult', 'child')),
  expires_at   timestamptz,
  used_by      uuid references auth.users (id) on delete set null,
  created_by   uuid references auth.users (id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now()
);

create index if not exists idx_invites_household_id
  on public.invites (household_id);
