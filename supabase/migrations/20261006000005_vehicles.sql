-- Phase 1 / Migration 5 of 10: vehicles

create table if not exists public.vehicles (
  id               uuid primary key default gen_random_uuid(),
  household_id     uuid not null references public.households (id) on delete cascade,
  name             text not null check (length(trim(name)) between 1 and 60),
  plate            text,
  current_odometer numeric(10,1) not null default 0 check (current_odometer >= 0),
  created_at       timestamptz not null default now()
);

create index if not exists idx_vehicles_household_id
  on public.vehicles (household_id);
