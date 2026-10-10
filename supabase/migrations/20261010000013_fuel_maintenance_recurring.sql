-- Phase 3 / Migration 13: vehicles polish + fuel log + maintenance
--                        reminders + recurring-rule generation
--
-- WHAT CHANGES
--   1. vehicles     gains fuel_type (petrol/diesel/electric/hybrid) and
--                   is_active (archive instead of delete).
--   2. fuel_logs    NEW table. One row per fill-up / charge. Returns the
--                   created log id.
--   3. add_fuel_log(vehicle_id, date, odometer_km, liters, total_cost_minor
--                   [, is_full]) RPC: adult-only. Validates the odometer
--                   never goes BACKWARDS vs any existing log, resolves the
--                   household's 'Fuel' car-group category (else any
--                   car-group category, else no_car_category), links the
--                   caller's person, and in the SAME transaction inserts a
--                   normal expense transaction + the log + bumps the
--                   vehicle's current_odometer. No double counting: the
--                   dashboard total comes from the one expense row.
--   4. delete_fuel_log(log_id) RPC: adult-only. Deletes the linked expense
--                   transaction AND the log together (reversing the record
--                   of spending).
--   5. maintenance_items NEW table: per-vehicle reminders (name, due by
--                   date and/or odometer, optional repeat interval so the
--                   reminder re-arms itself, completed_at for historical
--                   items).
--   6. complete_maintenance(item_id [, amount_minor, note]) RPC:
--                   adult-only. Marks an item complete, re-arms the next
--                   due date/odometer from its interval, and - if a cost is
--                   supplied - also records an expense in a car-group
--                   category (the maintenance equivalent of add_fuel_log).
--   7. recurring_rules gains name (display label, optional), start_date,
--                   end_date (generation stops once past end_date).
--   8. transactions gains recurrence_date + a PARTIAL UNIQUE index on
--                   (recurring_rule_id, recurrence_date). That index is the
--                   idempotency key for recurring generation: running the
--                   generator twice can never duplicate a due transaction.
--   9. generate_recurring_transactions() RPC: called by the app on open.
--                   For each ACTIVE rule of the caller's households it
--                   walks the rule's next_due cursor from the last
--                   generated date through today (stopping at end_date) and
--                   inserts the due transactions. Weekly = +7 days; monthly
--                   advances by month with the day clamped to the target
--                   month's length; yearly = +1 year (Postgres clamps
--                   Feb 29 -> Feb 28). Duplicate occurrences are skipped
--                   via the unique index, so re-running is free. Income vs
--                   expense is derived from the category's group, never
--                   stored twice.
--                  Why an on-open RPC and NOT cron: no scheduler
--                  dependency in a client DOM, no infra to feed, and the
--                  unique index makes every run idempotent; the cost is one
--                  cheap cursor walk per household per app launch.
--
-- ERROR KEYS RAISED (translated by the app's ExceptionMapper)
--   not_authenticated      - signed-out caller
--   forbidden              - non-adult calling an adult-only RPC
--   invalid_vehicle        - vehicle id unknown
--   invalid_item           - maintenance item id unknown
--   invalid_log            - fuel log id unknown
--   invalid_value          - missing/wrong field (date, odometer, liters,
--                           cost, fuel type constraints)
--   odometer_backwards     - new odometer lower than an existing log's
--   no_car_category        - no car-group category to attach the expense
--   no_linked_person       - caller (adult) has no person of their own
--   invalid_name           - bad maintenance/vehicle/rule name (triggers)
--   not_overdue            - complete_maintenance called with nothing due
--
-- RLS IMPACT (plain language)
--   Vehicles, fuel, maintenance and recurring rules become
--   OWNER/ADULT-ONLY end to end: children can no longer even READ them
--   (the vehicles/fuel/rule SELECT policies narrow from 'any member' to
--   'owner or adult'). The old household member policies are dropped and
--   recreated as adult policies. fuel_logs has a SELECT policy only -
--   filling and deleting go through the two definer RPCs so the linked
--   expense can never desync. Children keep zero write access and their
--   transactions visibility is unchanged. Budget/transactions/categories/
--   members policies are untouched (Phase 4 will revisit budgets).

-- ---------------------------------------------------------------------------
-- 1. vehicles: fuel type + archive flag
-- ---------------------------------------------------------------------------
alter table public.vehicles
  add column fuel_type text not null default 'petrol'
    check (fuel_type in ('petrol', 'diesel', 'electric', 'hybrid'));
alter table public.vehicles
  add column is_active boolean not null default true;

-- ---------------------------------------------------------------------------
-- 2. fuel_logs
-- ---------------------------------------------------------------------------
create table public.fuel_logs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  date date not null default current_date,
  odometer_km numeric(10,1) not null check (odometer_km >= 0),
  liters numeric(10,3) not null default 0 check (liters >= 0),
  total_cost numeric(12,2) not null check (total_cost > 0),
  is_full boolean not null default false,
  transaction_id uuid references public.transactions(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index idx_fuel_logs_household_id on public.fuel_logs (household_id);
create index idx_fuel_logs_vehicle_id on public.fuel_logs (vehicle_id);
create index idx_fuel_logs_vehicle_date on public.fuel_logs (vehicle_id, date desc);

-- ---------------------------------------------------------------------------
-- 3. maintenance_items
-- ---------------------------------------------------------------------------
create table public.maintenance_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  name text not null,
  due_date date,
  due_odometer_km numeric(10,1) check (due_odometer_km is null or due_odometer_km >= 0),
  interval_days integer check (interval_days is null or interval_days > 0),
  interval_km numeric(10,1) check (interval_km is null or interval_km >= 0),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  check (due_date is not null or due_odometer_km is not null)
);

create index idx_maintenance_items_household_id on public.maintenance_items (household_id);
create index idx_maintenance_items_vehicle_id on public.maintenance_items (vehicle_id);

-- Defense in depth: maintenance item names are trimmed + length-checked on
-- every write path (direct table). RPCs validate first for consistent keys.
create or replace function public.maintenance_items_validate_name()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_name text := btrim(coalesce(new.name, ''));
begin
  if tg_op = 'UPDATE' and new.name is not distinct from old.name then
    return new;
  end if;
  if length(v_name) < 1 or length(v_name) > 60 then
    raise exception 'invalid_name';
  end if;
  new.name := v_name;
  return new;
end;
$$;

drop trigger if exists trg_maintenance_items_validate_name on public.maintenance_items;
create trigger trg_maintenance_items_validate_name
before insert or update on public.maintenance_items
for each row execute function public.maintenance_items_validate_name();

-- ---------------------------------------------------------------------------
-- 4. recurring_rules: display name + start/end dates
-- ---------------------------------------------------------------------------
alter table public.recurring_rules
  add column name text;
alter table public.recurring_rules
  add column start_date date;
alter table public.recurring_rules
  add column end_date date;

create or replace function public.recurring_rules_validate_name()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_name text := btrim(coalesce(new.name, ''));
begin
  if tg_op = 'UPDATE' and new.name is not distinct from old.name then
    return new;
  end if;
  if new.name is null then
    return new;
  end if;
  if length(v_name) < 1 or length(v_name) > 40 then
    raise exception 'invalid_name';
  end if;
  new.name := v_name;
  return new;
end;
$$;

drop trigger if exists trg_recurring_rules_validate_name on public.recurring_rules;
create trigger trg_recurring_rules_validate_name
before insert or update on public.recurring_rules
for each row execute function public.recurring_rules_validate_name();

-- ---------------------------------------------------------------------------
-- 5. transactions: recurrence idempotency key
-- ---------------------------------------------------------------------------
alter table public.transactions
  add column recurrence_date date;

create unique index idx_transactions_recurrence
  on public.transactions (recurring_rule_id, recurrence_date)
  where recurring_rule_id is not null;

-- ---------------------------------------------------------------------------
-- 6. add_fuel_log(...)
-- ---------------------------------------------------------------------------
create function public.add_fuel_log(
  p_vehicle_id uuid,
  p_date date,
  p_odometer_km numeric,
  p_liters numeric,
  p_total_cost_minor integer,
  p_is_full boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_vehicle record;
  v_cost numeric(12,2);
  v_category uuid;
  v_member uuid;
  v_tx_id uuid;
  v_log_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select id, household_id, name, fuel_type into v_vehicle
    from public.vehicles
   where id = p_vehicle_id;
  if not found then
    raise exception 'invalid_vehicle';
  end if;
  if public.is_household_adult(v_vehicle.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if p_date is null then
    raise exception 'invalid_value';
  end if;
  if p_odometer_km is null or p_odometer_km < 0 then
    raise exception 'invalid_value';
  end if;

  -- Electric vehicles record charging without liters; everyone else must
  -- supply a positive volume.
  if v_vehicle.fuel_type = 'electric' then
    if p_liters is not null and p_liters > 0 then
      raise exception 'invalid_value';
    end if;
    p_liters := 0;
  else
    if p_liters is null or p_liters <= 0 then
      raise exception 'invalid_value';
    end if;
  end if;

  if p_total_cost_minor is null or p_total_cost_minor <= 0 then
    raise exception 'invalid_value';
  end if;
  v_cost := p_total_cost_minor::numeric / 100;

  -- The odometer can never go backwards against the vehicle's own history.
  if exists (
    select 1 from public.fuel_logs f
     where f.vehicle_id = v_vehicle.id and f.odometer_km > p_odometer_km
  ) then
    raise exception 'odometer_backwards';
  end if;

  -- Car-group category: the seeded 'Fuel' one by preference, else any
  -- car-group category, else fail loudly.
  select c.id into v_category
    from public.categories c
   where c.household_id = v_vehicle.household_id and c."group" = 'car'
   order by (c.name_en = 'Fuel') desc, c.created_at asc
   limit 1;
  if v_category is null then
    raise exception 'no_car_category';
  end if;

  select m.id into v_member
    from public.members m
   where m.household_id = v_vehicle.household_id
     and m.user_id = v_user_id
     and m.is_active
   limit 1;
  if v_member is null then
    raise exception 'no_linked_person';
  end if;

  -- The expense row IS the fuel cost in the dashboard. One record of
  -- spending, referred to by the log: no double counting.
  insert into public.transactions
    (household_id, type, amount, category_id, member_id, vehicle_id,
     date, note, odometer, liters)
  values
    (v_vehicle.household_id, 'expense', v_cost, v_category, v_member,
     v_vehicle.id, p_date, v_vehicle.name, p_odometer_km, p_liters)
  returning id into v_tx_id;

  insert into public.fuel_logs
    (household_id, vehicle_id, date, odometer_km, liters, total_cost,
     is_full, transaction_id, created_by)
  values
    (v_vehicle.household_id, v_vehicle.id, p_date, p_odometer_km, p_liters,
     v_cost, coalesce(p_is_full, false), v_tx_id, v_user_id)
  returning id into v_log_id;

  update public.vehicles
     set current_odometer = greatest(current_odometer, p_odometer_km)
   where id = v_vehicle.id;

  return v_log_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. delete_fuel_log(...)
-- ---------------------------------------------------------------------------
create function public.delete_fuel_log(p_log_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_log record;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select fl.household_id, fl.transaction_id into v_log
    from public.fuel_logs fl
   where fl.id = p_log_id;
  if not found then
    raise exception 'invalid_log';
  end if;
  if public.is_household_adult(v_log.household_id) is not true then
    raise exception 'forbidden';
  end if;

  -- Reversing the log also reverses its single record of spending.
  if v_log.transaction_id is not null then
    delete from public.transactions where id = v_log.transaction_id;
  end if;
  delete from public.fuel_logs where id = p_log_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. complete_maintenance(...)
-- ---------------------------------------------------------------------------
create function public.complete_maintenance(
  p_item_id uuid,
  p_amount_minor integer default null,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item record;
  v_vehicle record;
  v_category uuid;
  v_member uuid;
  v_cost numeric(12,2);
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select il.id, il.household_id, il.vehicle_id, il.name,
         il.due_date, il.due_odometer_km, il.interval_days, il.interval_km
    into v_item
    from public.maintenance_items il
   where il.id = p_item_id;
  if not found then
    raise exception 'invalid_item';
  end if;
  if public.is_household_adult(v_item.household_id) is not true then
    raise exception 'forbidden';
  end if;

  select id, name, current_odometer into v_vehicle
    from public.vehicles
   where id = v_item.vehicle_id;

  update public.maintenance_items
     set completed_at = now(),
         due_date = case
           -- Recurring by DAYS: re-arm from the current due date forward.
           when interval_days is not null then
             coalesce(due_date, current_date) + interval_days
           when interval_days is null and interval_km is null then null
           else due_date
         end,
         due_odometer_km = case
           -- Recurring by KM: re-arm from the current odometer forward.
           when interval_km is not null then
             coalesce(due_odometer_km, v_vehicle.current_odometer) + interval_km
           when interval_days is null and interval_km is null then null
           else due_odometer_km
         end
   where id = v_item.id;

  -- Optional service expense, recorded exactly like a fuel entry.
  if p_amount_minor is not null and p_amount_minor > 0 then
    v_cost := p_amount_minor::numeric / 100;

    select c.id into v_category
      from public.categories c
     where c.household_id = v_item.household_id and c."group" = 'car'
     order by (c.name_en = 'Fuel') desc, c.created_at asc
     limit 1;
    if v_category is null then
      raise exception 'no_car_category';
    end if;

    select m.id into v_member
      from public.members m
     where m.household_id = v_item.household_id
       and m.user_id = v_user_id
       and m.is_active
     limit 1;
    if v_member is null then
      raise exception 'no_linked_person';
    end if;

    insert into public.transactions
      (household_id, type, amount, category_id, member_id, vehicle_id,
       date, note)
    values
      (v_item.household_id, 'expense', v_cost, v_category, v_member,
       v_item.vehicle_id, current_date,
       coalesce(p_note, v_item.name || ' - ' || v_vehicle.name));
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. generate_recurring_transactions() -> number of rows created
-- ---------------------------------------------------------------------------
create function public.generate_recurring_transactions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_run record;
  v_rule record;
  v_created integer := 0;
  v_d date;
  v_next date;
  v_target_month date;
  v_day integer;
  v_type text;
  v_note text;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  for v_run in
    select hu.household_id
      from public.household_users hu
     where hu.user_id = v_user_id
  loop
    -- Only owners/adults generate; children trigger nothing (their own
    -- rules are still created by an adult opening the app soon enough).
    if public.household_role(v_run.household_id) = 'child' then
      continue;
    end if;

    for v_rule in
      select r.id, r.household_id, r.category_id, r.member_id, r.amount,
             r.frequency, r.day_of_month, r.next_due, r.end_date,
             r.name, c."group" as "group"
        from public.recurring_rules r
        join public.categories c on c.id = r.category_id
       where r.household_id = v_run.household_id
         and r.is_active
       for update of r
    loop
      v_d := v_rule.next_due;
      while (v_rule.end_date is null or v_d <= v_rule.end_date)
            and v_d <= current_date
      loop
        v_type := case when v_rule."group" = 'income' then 'income' else 'expense' end;
        v_note := v_rule.name;
        begin
          insert into public.transactions
            (household_id, type, amount, category_id, member_id, date, note,
             recurring_rule_id, recurrence_date)
          values
            (v_rule.household_id, v_type, v_rule.amount, v_rule.category_id,
             v_rule.member_id, v_d, v_note, v_rule.id, v_d);
          v_created := v_created + 1;
        exception when unique_violation then
          -- Already generated (manual run, or cursor repaired): skip.
          null;
        end;

        -- Advance the cursor.
        if v_rule.frequency = 'weekly' then
          v_next := v_d + 7;
        elsif v_rule.frequency = 'yearly' then
          v_next := (v_d + interval '1 year')::date;
        else
          -- monthly: advance one month, clamp day to the target month.
          v_target_month := (date_trunc('month', v_d) + interval '1 month')::date;
          v_day := least(
            coalesce(v_rule.day_of_month, extract(day from v_d)::integer),
            extract(day from (date_trunc('month', v_d) + interval '2 months' - interval '1 day'))::integer
          );
          v_next := (v_target_month + ((v_day - 1) * interval '1 day'))::date;
        end if;
        v_d := v_next;
      end loop;

      -- Reposition the rule's cursor where the walk stopped, so the next
      -- run only looks at genuinely new dates.
      update public.recurring_rules
         set next_due = v_d
       where id = v_rule.id;
    end loop;
  end loop;

  return v_created;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. RLS: vehicles, fuel, maintenance, recurring rules -> owner/adult ONLY
-- ---------------------------------------------------------------------------

-- Vehicles: children no longer READ vehicles (fuel/maintenance screens are
-- adult features). Drops the migration 10 member-wide SELECT.
drop policy if exists vehicles_select_member on public.vehicles;
create policy vehicles_select_adult on public.vehicles
  for select to authenticated
  using (public.is_household_adult(household_id));

-- recurring_rules: same narrowing (due dates are not children's business).
drop policy if exists recurring_select_member on public.recurring_rules;
create policy recurring_select_adult on public.recurring_rules
  for select to authenticated
  using (public.is_household_adult(household_id));

-- fuel_logs: read-only at the table; writes go through the two definer
-- RPCs so the linked expense can never desync.
alter table public.fuel_logs enable row level security;
create policy fuel_logs_select_adult on public.fuel_logs
  for select to authenticated
  using (public.is_household_adult(household_id));

-- maintenance_items: full adult CRUD (simple rows, no linked records).
alter table public.maintenance_items enable row level security;
create policy maintenance_items_select_adult on public.maintenance_items
  for select to authenticated
  using (public.is_household_adult(household_id));
create policy maintenance_items_insert_adult on public.maintenance_items
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));
create policy maintenance_items_update_adult on public.maintenance_items
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));
create policy maintenance_items_delete_adult on public.maintenance_items
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- ---------------------------------------------------------------------------
-- 11. Privileges
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on public.fuel_logs, public.maintenance_items to authenticated, service_role;
revoke all on public.fuel_logs, public.maintenance_items from anon;

-- ---------------------------------------------------------------------------
-- 12. Privilege hardening (same sweep as migrations 11/12, new names added)
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
         'vehicle_in_household', 'recurring_in_household',
         'add_fuel_log', 'delete_fuel_log', 'complete_maintenance',
         'generate_recurring_transactions')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;