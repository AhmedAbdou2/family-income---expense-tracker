-- Phase 1 / Migration 7 of 10: transactions
--
-- ONE table for all money movement. "General", "car" and "fixed" are
-- category groups (migration 4), NOT separate tables.
-- Money is numeric(12,2): the app sends/reads decimal strings and keeps
-- integer minor units in Dart logic (see AGENTS.md).

create table if not exists public.transactions (
  id                uuid primary key default gen_random_uuid(),
  household_id      uuid not null references public.households (id) on delete cascade,
  type              text not null check (type in ('income', 'expense')),
  amount            numeric(12,2) not null check (amount > 0),
  category_id       uuid not null references public.categories (id) on delete restrict,
  member_id         uuid not null references public.members (id) on delete restrict,
  vehicle_id        uuid references public.vehicles (id) on delete set null,
  date              date not null default current_date,
  note              text,
  attachment_url    text,
  odometer          numeric(10,1) check (odometer is null or odometer >= 0),
  liters            numeric(8,2) check (liters is null or liters >= 0),
  recurring_rule_id uuid references public.recurring_rules (id) on delete set null,
  -- Nullable so deleting a login never destroys the family's history.
  created_by        uuid references auth.users (id) on delete set null default auth.uid(),
  created_at        timestamptz not null default now(),
  check (odometer is null or liters is null or type = 'expense')
);

-- Required index: household + date (monthly dashboards, lists, exports).
create index if not exists idx_transactions_household_date
  on public.transactions (household_id, date desc);

create index if not exists idx_transactions_household_member_date
  on public.transactions (household_id, member_id, date desc);

create index if not exists idx_transactions_household_category
  on public.transactions (household_id, category_id);
