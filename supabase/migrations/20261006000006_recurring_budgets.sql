-- Phase 1 / Migration 6 of 10: recurring_rules + budgets
-- (Must precede transactions: transactions.recurring_rule_id references it.)

create table if not exists public.recurring_rules (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households (id) on delete cascade,
  category_id   uuid not null references public.categories (id) on delete restrict,
  member_id     uuid not null references public.members (id) on delete restrict,
  amount        numeric(12,2) not null check (amount > 0),
  frequency     text not null check (frequency in ('weekly', 'monthly', 'yearly')),
  day_of_month  smallint check (day_of_month between 1 and 31),
  next_due      date not null,
  is_active     boolean not null default true,
  created_by    uuid references auth.users (id) on delete set null default auth.uid(),
  created_at    timestamptz not null default now()
);

create index if not exists idx_recurring_rules_household_id
  on public.recurring_rules (household_id);
create index if not exists idx_recurring_rules_next_due
  on public.recurring_rules (next_due) where is_active;

create table if not exists public.budgets (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  category_id  uuid references public.categories (id) on delete cascade,
  member_id    uuid references public.members (id) on delete cascade,
  amount       numeric(12,2) not null check (amount > 0),
  period       text not null default 'monthly' check (period in ('weekly', 'monthly', 'yearly')),
  created_at   timestamptz not null default now(),
  check (category_id is not null or member_id is not null)
);

create index if not exists idx_budgets_household_id
  on public.budgets (household_id);
