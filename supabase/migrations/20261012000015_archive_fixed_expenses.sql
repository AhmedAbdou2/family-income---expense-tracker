-- ===================================================================
-- 15. Archive fixed commitments instead of hard-deleting them
-- ===================================================================
-- BUG: deleting a recurring rule (with "Keep already posted
-- transactions") used `delete from recurring_rules`, and
-- `transactions.recurring_rule_id` references `recurring_rules(id)`
-- with `on delete set null`. So the posted, already-spent rows survived
-- but lost their link. The dashboard counts a posted fixed expense by
-- `recurring_rule_id is not null`, so those rows silently became
-- "ordinary" expenses: "Posted" dropped and "Left after fixed" rose
-- even though the money was already spent.
--
-- FIX: never hard-delete a rule. Archive it instead:
--   * new `archived_at timestamptz` (null = live). Archived rules are
--     inactive, hidden from the Fixed expenses list, and are skipped by
--     the generator, but their rows and the transactions they posted
--     keep their `recurring_rule_id` link - so past/current month
--     figures do not move.
--   * `archive_recurring_rule(rule, delete_month_transactions)` does the
--     whole thing in ONE server-side call (atomic): optionally delete
--     this month's posted rows for that rule, then archive. On any
--     failure nothing is deleted.
--   * direct DELETE on `recurring_rules` is revoked from
--     `authenticated`, so a rule can only be archived, never dropped.
--
-- Plain-language RLS impact:
--   * Rows do not become visible/hidden differently: a member still
--     SELECTs the household's rules, archive or not (the app filters
--     archived ones out of the list). A child still sees nothing.
--   * The only *new* power is `archive_recurring_rule`, which an owner
--     or adult may call for a rule of their own household; a child or
--     an outsider gets `forbidden`, and a rule from another household
--     is invisible (`invalid_rule`).
--   * `authenticated` loses the ability to DELETE rules outright.
--
-- Already hard-deleted rules: unrecoverable. Their posted transactions
-- became ordinary expenses and stay that way; re-creating the rule will
-- not re-link them. Only future archives are safe.
-- ===================================================================

-- ---------------------------------------------------------------------------
-- 1. archived_at column
-- ---------------------------------------------------------------------------
alter table public.recurring_rules
  add column if not exists archived_at timestamptz;

comment on column public.recurring_rules.archived_at is
  'When set, the rule is archived: inactive, hidden from the list, never '
  'generated again, but its posted transactions keep their link.';

-- ---------------------------------------------------------------------------
-- 2. generate_recurring_transactions(): ignore archived rules
--    (identical to migration 14 + `and r.archived_at is null`)
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
         and r.archived_at is null
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
-- 3. archive_recurring_rule(): atomic archive (+ optional month purge)
-- ---------------------------------------------------------------------------
-- One call, one transaction: either everything succeeds or nothing
-- changes. `p_delete_month_transactions` only ever touches rows this
-- rule posted in the CURRENT calendar month.
create or replace function public.archive_recurring_rule(
  p_rule_id uuid,
  p_delete_month_transactions boolean default false
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_rule record;
  v_deleted integer := 0;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select r.id, r.household_id, r.archived_at
    into v_rule
    from public.recurring_rules r
   where r.id = p_rule_id
   for update;

  if not found then
    raise exception 'invalid_rule';
  end if;

  -- Helpers return NULL for non-members, so `is not true` covers both
  -- "not a member" and "not an adult".
  if public.is_household_adult(v_rule.household_id) is not true then
    raise exception 'forbidden';
  end if;

  if v_rule.archived_at is not null then
    raise exception 'already_archived';
  end if;

  if p_delete_month_transactions then
    delete from public.transactions t
     where t.recurring_rule_id = p_rule_id
       and t.household_id = v_rule.household_id
       and t.date >= date_trunc('month', current_date)::date
       and t.date < (date_trunc('month', current_date) + interval '1 month')::date;
    get diagnostics v_deleted = row_count;
  end if;

  update public.recurring_rules
     set is_active = false,
         archived_at = now()
   where id = p_rule_id;

  return v_deleted;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Lock down direct DELETE on recurring_rules
-- ---------------------------------------------------------------------------
drop policy if exists "recurring_delete_adult" on public.recurring_rules;
revoke delete on public.recurring_rules from authenticated, anon;

-- ---------------------------------------------------------------------------
-- 5. Privilege hardening (same sweep as migrations 11/12/13/14)
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
         'generate_recurring_transactions', 'archive_recurring_rule')
  loop
    execute format('grant execute on function %s to authenticated;', r.proc);
  end loop;

  execute 'revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated, service_role';
end $$;
