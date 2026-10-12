-- ===================================================================
-- 16. Budgets: a monthly limit per category + one overall limit
-- ===================================================================
-- The `budgets` table existed since migration 6 but was never used by the
-- app. It allowed either a category budget OR a per-person budget and a
-- weekly/monthly/yearly period. Phase 4 uses it for ONE thing: a monthly
-- limit per category, plus at most one overall monthly limit.
--
-- WHAT CHANGES
--   1. `budgets` gains `is_active` (pause/resume) and drops the unused
--      `member_id` column and the old "category or member" check.
--   2. Two partial unique indexes enforce "one limit per category per
--      household" and "one overall limit per household".
--   3. Writes move behind four SECURITY DEFINER RPCs
--      (set_category_budget / set_overall_budget / set_budget_active /
--      delete_budget). Direct INSERT/UPDATE/DELETE on `budgets` is
--      revoked from `authenticated`, so the RPCs are the only write path.
--   4. A `monthly_totals()` RPC returns income/expense totals per month
--      for a household (used by the 6-month Reports chart). It exists so
--      the trend is aggregated in the database and never hits PostgREST's
--      1000-row response cap, and it uses the exact same definition of
--      income/expense as the dashboard (sum of `amount` by `type`).
--
-- AMENDMENT A SAFETY
--   A row with `category_id is null` used to mean a per-person budget
--   (member_id). Those rows must NOT silently become the overall limit,
--   so this migration ABORTS if any such row exists. Rows that carry a
--   category_id are kept as category limits.
--
-- ERROR KEYS RAISED (translated by the app's ExceptionMapper)
--   not_authenticated - no session
--   forbidden         - caller is not an owner/adult of the household
--   invalid_category  - category is missing or from another household
--   invalid_budget    - unknown / invisible budget id
--   invalid_value     - amount <= 0, > numeric(12,2) range, or finer
--                       than 2 decimals; bad monthly_totals range
--
-- RLS IMPACT (plain language)
--   Before: every member (children too) could READ the household's
--   budgets, and owner/adult could write the table directly.
--   After:  budgets are owner/adult-only to read (a child sees ZERO
--   rows), and NOBODY can write the table directly - all budget writes
--   go through the RPCs, which reject a child/outsider (`forbidden`) and
--   reject a category that is not in your household (`invalid_category`).
--   `monthly_totals` is owner/adult-only as well. No other table, policy
--   or role changes.
-- ===================================================================

-- ---------------------------------------------------------------------------
-- 1. Amendment A guard: refuse to reinterpret legacy per-person rows
-- ---------------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.budgets where category_id is null;
  if n > 0 then
    raise exception
      'Migration 16 aborted: % budget row(s) have a null category_id. '
      'Those are legacy per-person budgets and cannot be turned into the '
      'overall monthly limit. Review and delete them, then re-run this '
      'migration.', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. budgets: is_active, drop the dead member_id + old check, uniqueness
-- ---------------------------------------------------------------------------
alter table public.budgets
  add column if not exists is_active boolean not null default true;

comment on column public.budgets.is_active is
  'When false the limit is paused: kept on the Budgets screen but ignored '
  'by progress and alerts. Setting a limit again resumes it.';

comment on column public.budgets.category_id is
  'The category this monthly limit applies to, or NULL for the single '
  'overall monthly limit of the household.';

-- The old check allowed a member-scoped budget; the new model is
-- category-or-overall only.
alter table public.budgets drop constraint if exists budgets_check;

alter table public.budgets drop column if exists member_id;

-- One limit per category per household (paused rows still own the slot).
create unique index if not exists budgets_household_category_uniq
  on public.budgets (household_id, category_id)
  where category_id is not null;

-- At most one overall limit per household.
create unique index if not exists budgets_household_overall_uniq
  on public.budgets (household_id)
  where category_id is null;

-- ---------------------------------------------------------------------------
-- 3a. set_category_budget(): upsert a category limit (resumes if paused)
-- ---------------------------------------------------------------------------
create or replace function public.set_category_budget(
  p_household_id uuid,
  p_category_id uuid,
  p_amount numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  -- Helpers return NULL for non-members, so `is not true` covers both
  -- "not a member" and "not an adult".
  if public.is_household_adult(p_household_id) is not true then
    raise exception 'forbidden';
  end if;
  if p_category_id is null
     or public.category_in_household(p_household_id, p_category_id) is not true then
    raise exception 'invalid_category';
  end if;
  if p_amount is null or p_amount <= 0
     or p_amount <> round(p_amount, 2)
     or p_amount > 9999999999.99 then
    raise exception 'invalid_value';
  end if;

  insert into public.budgets (household_id, category_id, amount, period, is_active)
  values (p_household_id, p_category_id, p_amount, 'monthly', true)
  on conflict (household_id, category_id) where category_id is not null
  do update set amount = excluded.amount,
                period = 'monthly',
                is_active = true
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3b. set_overall_budget(): upsert the household's overall limit
-- ---------------------------------------------------------------------------
create or replace function public.set_overall_budget(
  p_household_id uuid,
  p_amount numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if public.is_household_adult(p_household_id) is not true then
    raise exception 'forbidden';
  end if;
  if p_amount is null or p_amount <= 0
     or p_amount <> round(p_amount, 2)
     or p_amount > 9999999999.99 then
    raise exception 'invalid_value';
  end if;

  insert into public.budgets (household_id, category_id, amount, period, is_active)
  values (p_household_id, null, p_amount, 'monthly', true)
  on conflict (household_id) where category_id is null
  do update set amount = excluded.amount,
                period = 'monthly',
                is_active = true
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3c. set_budget_active(): pause / resume one limit
-- ---------------------------------------------------------------------------
create or replace function public.set_budget_active(
  p_budget_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_household_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_active is null then
    raise exception 'invalid_value';
  end if;

  select b.household_id into v_household_id
    from public.budgets b
   where b.id = p_budget_id;

  if v_household_id is null then
    raise exception 'invalid_budget';
  end if;
  if public.is_household_adult(v_household_id) is not true then
    raise exception 'forbidden';
  end if;

  update public.budgets set is_active = p_active where id = p_budget_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3d. delete_budget(): remove one limit (category or overall)
-- ---------------------------------------------------------------------------
create or replace function public.delete_budget(p_budget_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_household_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select b.household_id into v_household_id
    from public.budgets b
   where b.id = p_budget_id;

  if v_household_id is null then
    raise exception 'invalid_budget';
  end if;
  if public.is_household_adult(v_household_id) is not true then
    raise exception 'forbidden';
  end if;

  delete from public.budgets where id = p_budget_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3e. monthly_totals(): income/expense per month, aggregated in the DB
-- ---------------------------------------------------------------------------
-- Returns integer MINOR units (numeric(12,2) * 100) so no float ever
-- crosses the wire. Months with no transactions are simply absent.
create or replace function public.monthly_totals(
  p_household_id uuid,
  p_start_month date,
  p_end_month date
)
returns table (month_start date, income_minor bigint, expense_minor bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if public.is_household_adult(p_household_id) is not true then
    raise exception 'forbidden';
  end if;
  if p_start_month is null or p_end_month is null
     or p_start_month >= p_end_month then
    raise exception 'invalid_value';
  end if;

  return query
    select date_trunc('month', t.date)::date as month_start,
           (coalesce(sum(t.amount)
             filter (where t.type = 'income'), 0) * 100)::bigint as income_minor,
           (coalesce(sum(t.amount)
             filter (where t.type = 'expense'), 0) * 100)::bigint as expense_minor
      from public.transactions t
     where t.household_id = p_household_id
       and t.date >= p_start_month
       and t.date < p_end_month
     group by 1
     order by 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. RLS: budgets read is owner/adult only; writes are RPC-only
-- ---------------------------------------------------------------------------
drop policy if exists "budgets_select_member" on public.budgets;
drop policy if exists "budgets_insert_adult" on public.budgets;
drop policy if exists "budgets_update_adult" on public.budgets;
drop policy if exists "budgets_delete_adult" on public.budgets;

-- "Only owners and adults can see the household's budget limits."
create policy "budgets_select_adult" on public.budgets
  for select to authenticated
  using (public.is_household_adult(household_id));

-- No INSERT / UPDATE / DELETE policies -> the RPCs are the only write path.
revoke insert, update, delete on public.budgets from authenticated, anon;

-- ---------------------------------------------------------------------------
-- 5. Privilege hardening (same sweep as migrations 11-15)
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
         'delete_budget', 'monthly_totals')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;
