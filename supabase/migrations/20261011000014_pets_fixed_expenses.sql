-- Phase 3.5 / Migration 14: pets + fixed-expense links + pet categories
--
-- WHAT CHANGES
--   1. categories gains a FIFTH group, 'pet'. The default pet categories
--      (Food, Litter, Vet, Vaccines, Grooming, Other) are seeded for every
--      EXISTING household here, and seed_default_categories() is updated so
--      every NEW household gets them at creation. The categories."group"
--      check constraint is recreated to allow the new value.
--   2. pets NEW table: the household's animals (name, type, optional birth
--      date + notes, archive via is_active). Owner/adult only end to end,
--      exactly like vehicles - a child gets ZERO access.
--   3. transactions gains a nullable pet_id (on delete set null) so an
--      expense can be attributed to a pet. The INSERT/UPDATE policies gain
--      the same-household integrity check used for vehicle_id.
--   4. recurring_rules gains nullable vehicle_id and pet_id links, so a
--      "fixed" commitment can be tied to a car or a pet (member_id already
--      links a person). generate_recurring_transactions() carries them onto
--      the transactions it posts.
--   5. pet_in_household(household_id, pet_id) helper, mirroring
--      vehicle_in_household, for the transactions integrity policies.
--
-- ERROR KEYS RAISED (translated by the app's ExceptionMapper)
--   invalid_name  - blank / overlong pet name (trigger, any write path)
--   (no new RPC in this phase; pets are plain owner/adult table CRUD)
--
-- RLS IMPACT (plain language)
--   Pets are owner/adult-only: children and outsiders see no pet rows and
--   cannot write them. A transaction may reference a pet only if that pet
--   lives in the SAME household (same rule as vehicles), so nobody can
--   smuggle a foreign pet id into their spending. Recurring rules keep
--   their existing owner/adult policies; the two new link columns are
--   plain columns on an already-locked table. Categories stay readable by
--   everyone (children need them to spend); only owner/adult write them.

-- ---------------------------------------------------------------------------
-- 1. Pet category group
-- ---------------------------------------------------------------------------
-- Recreate the group check to admit 'pet'. Postgres names a column check
-- `<table>_<column>_check`, i.e. categories_group_check.
alter table public.categories
  drop constraint if exists categories_group_check;
alter table public.categories
  add constraint categories_group_check
  check ("group" in ('general', 'car', 'fixed', 'income', 'pet'));

-- Seed the six pet categories into every EXISTING household (the seeder
-- below only runs for households created after this migration).
insert into public.categories
  (household_id, "group", name_en, name_ar, icon, color, is_default)
select h.id, 'pet', v.name_en, v.name_ar, v.icon, v.color, true
  from public.households h
  cross join (values
    ('Pet Food', 'طعام الحيوانات', 'restaurant',          '#FFA726'),
    ('Litter',   'رمل القطط',      'delete_sweep',        '#8D6E63'),
    ('Vet',      'طبيب بيطري',     'medical_services',    '#EC407A'),
    ('Vaccines', 'تطعيمات',        'vaccines',            '#26A69A'),
    ('Grooming', 'تنظيف وتجميل',   'content_cut',         '#29B6F6'),
    ('Other',    'أخرى',           'more_horiz',          '#78909C')
  ) as v(name_en, name_ar, icon, color)
 where not exists (
   select 1 from public.categories c
    where c.household_id = h.id and c."group" = 'pet'
 );

-- ---------------------------------------------------------------------------
-- 2. pets
-- ---------------------------------------------------------------------------
create table public.pets (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name         text not null,
  type         text not null default 'other'
               check (type in ('cat', 'dog', 'bird', 'fish', 'other')),
  birth_date   date,
  notes        text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

create index idx_pets_household_id on public.pets (household_id);

-- Pet names are trimmed + length-checked on every write path.
create or replace function public.pets_validate_name()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_name text := btrim(coalesce(new.name, ''));
begin
  if tg_op = 'UPDATE' and new.name is not distinct from old.name then
    return new;
  end if;
  if length(v_name) < 1 or length(v_name) > 40 then
    raise exception 'invalid_name';
  end if;
  new.name := v_name;
  return new;
end;
$$;

drop trigger if exists trg_pets_validate_name on public.pets;
create trigger trg_pets_validate_name
before insert or update on public.pets
for each row execute function public.pets_validate_name();

-- ---------------------------------------------------------------------------
-- 3. transactions.pet_id
-- ---------------------------------------------------------------------------
alter table public.transactions
  add column pet_id uuid references public.pets (id) on delete set null;

create index idx_transactions_household_pet
  on public.transactions (household_id, pet_id);

-- ---------------------------------------------------------------------------
-- 4. recurring_rules: vehicle + pet links
-- ---------------------------------------------------------------------------
alter table public.recurring_rules
  add column vehicle_id uuid references public.vehicles (id) on delete set null;
alter table public.recurring_rules
  add column pet_id uuid references public.pets (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 5. pet_in_household helper (mirrors vehicle_in_household)
-- ---------------------------------------------------------------------------
create or replace function public.pet_in_household(p_household_id uuid, p_pet_id uuid)
returns boolean
language sql stable security definer set search_path = public parallel safe
as $$
  select exists (select 1 from public.pets p
                 where p.id = p_pet_id and p.household_id = p_household_id);
$$;

-- ---------------------------------------------------------------------------
-- 6. seed_default_categories(): add the pet group for NEW households
-- ---------------------------------------------------------------------------
create or replace function public.seed_default_categories(p_household_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.categories (household_id, "group", name_en, name_ar, icon, color, is_default)
  values
    -- general (13)
    (p_household_id, 'general', 'Food',        'طعام',          'restaurant',          '#EF5350', true),
    (p_household_id, 'general', 'Groceries',   'بقالة',         'shopping_basket',     '#66BB6A', true),
    (p_household_id, 'general', 'Electricity', 'كهرباء',        'bolt',                '#FDD835', true),
    (p_household_id, 'general', 'Water',       'مياه',          'water_drop',          '#42A5F5', true),
    (p_household_id, 'general', 'Gas',         'غاز',           'local_fire_department','#FF7043', true),
    (p_household_id, 'general', 'Internet',    'إنترنت',        'wifi',                '#26C6DA', true),
    (p_household_id, 'general', 'Mobile',      'هاتف',          'phone_iphone',        '#5C6BC0', true),
    (p_household_id, 'general', 'Health',      'صحة',           'health_and_safety',   '#EC407A', true),
    (p_household_id, 'general', 'Education',   'تعليم',         'school',              '#AB47BC', true),
    (p_household_id, 'general', 'Entertainment','ترفيه',        'movie',               '#29B6F6', true),
    (p_household_id, 'general', 'Clothes',     'ملابس',         'checkroom',           '#8D6E63', true),
    (p_household_id, 'general', 'Gifts',       'هدايا',         'gift',                '#FFA726', true),
    (p_household_id, 'general', 'Other',       'أخرى',          'more_horiz',          '#78909C', true),
    -- car (8)
    (p_household_id, 'car', 'Fuel',       'وقود',         'local_gas_station', '#FFA726', true),
    (p_household_id, 'car', 'Maintenance','صيانة',         'build',             '#5C6BC0', true),
    (p_household_id, 'car', 'Oil Change', 'تغيير الزيت',  'oil_barrel',        '#795548', true),
    (p_household_id, 'car', 'Insurance',  'تأمين',        'shield',            '#26A69A', true),
    (p_household_id, 'car', 'License',    'رخصة',          'card_membership',   '#42A5F5', true),
    (p_household_id, 'car', 'Car Wash',   'غسيل السيارة', 'local_car_wash',    '#29B6F6', true),
    (p_household_id, 'car', 'Fines',      'غرامات',       'gavel',             '#EF5350', true),
    (p_household_id, 'car', 'Installment','قسط السيارة',  'payments',          '#7E57C2', true),
    -- fixed (6)
    (p_household_id, 'fixed', 'Rent',           'إيجار',        'home',         '#EF5350', true),
    (p_household_id, 'fixed', 'Installments',   'أقساط',        'credit_card',  '#7E57C2', true),
    (p_household_id, 'fixed', 'Subscriptions',  'اشتراكات',     'subscriptions','#26C6DA', true),
    (p_household_id, 'fixed', 'School Fees',    'رسوم مدرسية',  'school',       '#AB47BC', true),
    (p_household_id, 'fixed', 'Savings Circle', 'جمعية',        'savings',      '#66BB6A', true),
    (p_household_id, 'fixed', 'Utilities',      'فواتير الخدمات','receipt_long', '#FDD835', true),
    -- income (4)
    (p_household_id, 'income', 'Salary',      'راتب',          'payments',   '#66BB6A', true),
    (p_household_id, 'income', 'Extra Income','دخل إضافي',     'add_circle', '#42A5F5', true),
    (p_household_id, 'income', 'Rent Income', 'دخل إيجار',     'home',       '#26A69A', true),
    (p_household_id, 'income', 'Other',       'أخرى',          'more_horiz', '#78909C', true),
    -- pet (6)
    (p_household_id, 'pet', 'Pet Food', 'طعام الحيوانات', 'restaurant',       '#FFA726', true),
    (p_household_id, 'pet', 'Litter',   'رمل القطط',      'delete_sweep',     '#8D6E63', true),
    (p_household_id, 'pet', 'Vet',      'طبيب بيطري',     'medical_services', '#EC407A', true),
    (p_household_id, 'pet', 'Vaccines', 'تطعيمات',        'vaccines',         '#26A69A', true),
    (p_household_id, 'pet', 'Grooming', 'تنظيف وتجميل',   'content_cut',      '#29B6F6', true),
    (p_household_id, 'pet', 'Other',    'أخرى',           'more_horiz',       '#78909C', true);
$$;

-- ---------------------------------------------------------------------------
-- 7. generate_recurring_transactions(): carry vehicle_id + pet_id
-- ---------------------------------------------------------------------------
create or replace function public.generate_recurring_transactions()
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
             r.name, r.vehicle_id, r.pet_id, c."group" as "group"
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
            (household_id, type, amount, category_id, member_id, vehicle_id,
             pet_id, date, note, recurring_rule_id, recurrence_date)
          values
            (v_rule.household_id, v_type, v_rule.amount, v_rule.category_id,
             v_rule.member_id, v_rule.vehicle_id, v_rule.pet_id, v_d, v_note,
             v_rule.id, v_d);
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
-- 8. RLS: pets owner/adult only; transactions integrity includes pet_id
-- ---------------------------------------------------------------------------
alter table public.pets enable row level security;

create policy pets_select_adult on public.pets
  for select to authenticated
  using (public.is_household_adult(household_id));
create policy pets_insert_adult on public.pets
  for insert to authenticated
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));
create policy pets_update_adult on public.pets
  for update to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id))
  with check (public.is_household_member(household_id) and public.is_household_adult(household_id));
create policy pets_delete_adult on public.pets
  for delete to authenticated
  using (public.is_household_member(household_id) and public.is_household_adult(household_id));

-- transactions INSERT/UPDATE: add the same-household check for pet_id.
drop policy if exists "transactions_insert" on public.transactions;
create policy "transactions_insert" on public.transactions
  for insert to authenticated
  with check (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
    and public.member_in_household(household_id, member_id)
    and public.category_in_household(household_id, category_id)
    and (vehicle_id is null or public.vehicle_in_household(household_id, vehicle_id))
    and (pet_id is null or public.pet_in_household(household_id, pet_id))
    and (recurring_rule_id is null or public.recurring_in_household(household_id, recurring_rule_id))
  );

drop policy if exists "transactions_update" on public.transactions;
create policy "transactions_update" on public.transactions
  for update to authenticated
  using (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
  )
  with check (
    public.is_household_member(household_id)
    and (
      public.is_household_adult(household_id)
      or public.owns_member_row(household_id, member_id)
    )
    and public.member_in_household(household_id, member_id)
    and public.category_in_household(household_id, category_id)
    and (vehicle_id is null or public.vehicle_in_household(household_id, vehicle_id))
    and (pet_id is null or public.pet_in_household(household_id, pet_id))
    and (recurring_rule_id is null or public.recurring_in_household(household_id, recurring_rule_id))
  );

-- ---------------------------------------------------------------------------
-- 9. Privileges
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on public.pets to authenticated, service_role;
revoke all on public.pets from anon;

-- ---------------------------------------------------------------------------
-- 10. Privilege hardening (same sweep as migrations 11/12/13)
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
         'generate_recurring_transactions')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;
