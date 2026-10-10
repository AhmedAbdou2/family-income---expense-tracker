-- ===================================================================
-- RLS ISOLATION TEST - Phase 1 + 2 + 2.5 + 3 extensions
-- ===================================================================
-- Proves that a user from household B cannot SELECT / INSERT / UPDATE /
-- DELETE any row of household A, and that child-role restrictions hold.
--
-- Phase 2 additions (section 5):
--   * a person-bound invite auto-links members.user_id on accept;
--   * a linked child can SELECT/INSERT transactions ONLY for their own
--     linked member;
--   * a child cannot EDIT categories, members or budgets (0 rows touched);
--   * member-bound invite edge cases (member_linked at create,
--     already_linked at accept).
--
-- Phase 2.5 additions (section 6):
--   * join-only invite: the joiner CHOOSES their name (trim + 1..40,
--     a bad name never consumes the code);
--   * claim_member for legacy logins that have a household but no
--     person of their own (twice -> member_linked, no household ->
--     not_member, name validation);
--   * rename_member matrix (owner renames anyone, everyone else only
--     their own person, foreign household -> invalid_member);
--   * update_household_role matrix (non-owner forbidden, promotion TO
--     owner allowed, self -> cannot_change_own_role, sole-owner
--     self-demote -> last_owner FIRST, child_requires_member,
--     invalid_role, invalid_member);
--   * leave_household / remove_household_login (cannot_remove_self,
--     last_owner, link cleared, person + transactions kept, removed
--     login loses ALL access immediately);
--   * direct-write lockdown on members (no attaching a login on
--     INSERT, no direct name/user_id UPDATE at all, linked persons
--     undeletable, is_active UPDATE still allowed, name trigger trims
--     + validates, no direct role UPDATE on household_users);
--   * accept edge cases (login_linked, foreign person ->
--     invalid_member, code never consumed on any failure).
--
-- Phase 3 additions (section 8):
--   * add_fuel_log writes the log + exactly one linked car expense and
--     bumps the vehicle odometer; electric vehicles take no liters;
--     backwards/zero/negative/null inputs raise (odometer_backwards /
--     invalid_value) and write nothing; delete_fuel_log also deletes the
--     linked expense;
--   * maintenance_items adult CRUD + name trigger; complete_maintenance
--     re-arms by days and by km and can record one service expense;
--   * generate_recurring_transactions: 9 rows from weekly/monthly/
--     end-capped rules, idempotent on a second run, income derived from
--     the category group, future rules produce nothing, children never
--     generate;
--   * children + outsiders are fully locked out (no SELECT, no direct
--     writes, RPCs raise forbidden) of vehicles / fuel / maintenance /
--     recurring rules.
--
-- Logins used: A + B (isolation), C + D + E (phase 2), F + G + H
-- (phase 2.5 joiners/legacy), J + K + L (role / leave / remove cast).
--
-- HOW TO RUN: paste this ENTIRE file into the Supabase SQL editor and run
-- it. It executes inside ONE transaction and always ROLLS BACK, so it
-- leaves no data behind. Success = green notice below; any failure =
-- red error starting with "FAIL:" or "TEST SETUP FAILED:".
--
-- Prerequisite: migrations 1..13 have been run in that order.
-- ===================================================================

begin;

-- --------------------------------------------------------------------
-- 0. Probe: this session must be able to act as the "authenticated" role
--    (the SQL editor runs as "postgres"). If this line errors with
--    `permission denied to set role "authenticated"`, tell the developer -
--    the alternative test variant will be provided.
-- --------------------------------------------------------------------
set local role authenticated;
set local role none;

-- --------------------------------------------------------------------
-- 1. Two throw-away logins (rolled back at the end).
-- --------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-4111-8111-111111111111',
   'authenticated', 'authenticated', 'rls-test-a@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-4222-8222-222222222222',
   'authenticated', 'authenticated', 'rls-test-b@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;

-- --------------------------------------------------------------------
-- 2. As USER A: build a small household (household + person + category
--    are created through the app's own entry points / RLS-allowed writes).
-- --------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- Migration 12: create_household now also creates + links the owner's
-- own person, so no manual member insert is needed anymore.
select set_config('test.hh_a', public.create_household('Test HH A', 'SAR', 'A Person')::text, false);

select set_config('test.member_a', (
  select m.id from public.members m
  where m.household_id = current_setting('test.hh_a')::uuid
    and m.name = 'A Person'
  limit 1)::text, false);

-- The owner's person must be linked to the owner's login right away.
do $$
declare n int;
begin
  select count(*) into n from public.members m
   where m.id = current_setting('test.member_a')::uuid
     and m.user_id = '11111111-1111-4111-8111-111111111111';
  if n <> 1 then
    raise exception 'TEST SETUP FAILED: owner person not linked to owner login';
  end if;
end $$;

select set_config('test.category_a', (
  select c.id from public.categories c
  where c.household_id = current_setting('test.hh_a')::uuid
    and c."group" = 'general'
  limit 1)::text, false);

insert into public.transactions (household_id, type, amount, category_id, member_id, date, created_by)
values (current_setting('test.hh_a')::uuid, 'expense', 25.50,
        current_setting('test.category_a')::uuid,
        current_setting('test.member_a')::uuid, current_date, auth.uid());

select set_config('test.txn_a', (
  select t.id from public.transactions t
  where t.household_id = current_setting('test.hh_a')::uuid
  limit 1)::text, false);

-- Sanity: A must see exactly own household's seed data.
do $$
declare n int;
begin
  select count(*) into n from public.households;
  if n <> 1 then raise exception 'TEST SETUP FAILED: A sees % households (expected 1)', n; end if;
  select count(*) into n from public.transactions;
  if n <> 1 then raise exception 'TEST SETUP FAILED: A sees % transactions (expected 1)', n; end if;
end $$;

-- --------------------------------------------------------------------
-- 3. As USER B (no household yet): household A must be completely
--    invisible and untouchable.
-- --------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';
set local request.jwt.claim.sub to '22222222-2222-4222-8222-222222222222';

do $$
declare n int;
begin
  -- 3a. SELECT: B must see ZERO rows of household A in every table.
  select count(*) into n from public.households;
  if n <> 0 then raise exception 'FAIL: B can see % households (expected 0)', n; end if;
  select count(*) into n from public.household_users;
  if n <> 0 then raise exception 'FAIL: B can see % household_users rows (expected 0)', n; end if;
  select count(*) into n from public.members;
  if n <> 0 then raise exception 'FAIL: B can see % members rows (expected 0)', n; end if;
  select count(*) into n from public.categories;
  if n <> 0 then raise exception 'FAIL: B can see % categories rows (expected 0)', n; end if;
  select count(*) into n from public.vehicles;
  if n <> 0 then raise exception 'FAIL: B can see % vehicles rows (expected 0)', n; end if;
  select count(*) into n from public.transactions;
  if n <> 0 then raise exception 'FAIL: B can see % transactions rows (expected 0)', n; end if;
  select count(*) into n from public.recurring_rules;
  if n <> 0 then raise exception 'FAIL: B can see % recurring_rules rows (expected 0)', n; end if;
  select count(*) into n from public.budgets;
  if n <> 0 then raise exception 'FAIL: B can see % budgets rows (expected 0)', n; end if;
  select count(*) into n from public.invites;
  if n <> 0 then raise exception 'FAIL: B can see % invites rows (expected 0)', n; end if;

  -- 3b. INSERT: writing into household A must be denied by the policy.
  begin
    insert into public.members (household_id, name)
    values (current_setting('test.hh_a')::uuid, 'intruder');
    raise exception 'FAIL: B inserted a member into A''s household';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.transactions (household_id, type, amount, category_id, member_id, date)
    values (current_setting('test.hh_a')::uuid, 'expense', 10,
            current_setting('test.category_a')::uuid,
            current_setting('test.member_a')::uuid, current_date);
    raise exception 'FAIL: B inserted a transaction into A''s household';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.categories (household_id, "group", name_en, name_ar)
    values (current_setting('test.hh_a')::uuid, 'general', 'Evil', 'شرير');
    raise exception 'FAIL: B inserted a category into A''s household';
  exception when insufficient_privilege then null;
  end;

  -- 3c. UPDATE: must silently touch 0 rows (row invisible = row protected).
  update public.transactions
     set amount = 999
   where id = current_setting('test.txn_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: B updated % rows of A''s transactions', n; end if;

  -- 3c2. Person names can no longer be written directly AT ALL (the
  --      name/link columns lost their UPDATE grant in migration 12):
  --      rejected before RLS even runs -> rename_member() only.
  begin
    update public.members
       set name = 'pwned'
     where household_id = current_setting('test.hh_a')::uuid;
    raise exception 'FAIL: B updated A''s member names directly';
  exception when insufficient_privilege then null;
  end;

  update public.households
     set name = 'pwned'
   where id = current_setting('test.hh_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: B updated % rows of A''s households', n; end if;

  -- 3d. DELETE: must silently delete 0 rows.
  delete from public.transactions
   where id = current_setting('test.txn_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: B deleted % rows of A''s transactions', n; end if;

  delete from public.members
   where household_id = current_setting('test.hh_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: B deleted % rows of A''s members', n; end if;

  delete from public.households
   where id = current_setting('test.hh_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: B deleted % rows of A''s households', n; end if;

  -- 3e. B cannot create household_users rows by hand (no INSERT policy).
  begin
    insert into public.household_users (household_id, user_id, role)
    values (current_setting('test.hh_a')::uuid, auth.uid(), 'adult');
    raise exception 'FAIL: B inserted themselves into household A directly';
  exception when insufficient_privilege then null;
  end;

  -- 3f. B cannot mint invite codes for household A (no INSERT policy).
  begin
    insert into public.invites (code, household_id, role)
    values ('ZZZZZZ', current_setting('test.hh_a')::uuid, 'adult');
    raise exception 'FAIL: B inserted an invite for household A directly';
  exception when insufficient_privilege then null;
  end;

  -- 3g. Invented invite codes must be rejected.
  begin
    perform public.accept_invite('NOPE12');
    raise exception 'FAIL: B accepted a non-existent invite code';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invite_not_found' then raise; end if;
  end;
end $$;

-- --------------------------------------------------------------------
-- 4. The LEGITIMATE path: A invites B as a child. Then prove that a
--    child inside household A still cannot touch A's data.
-- --------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

select set_config('test.invite', public.create_invite(
  current_setting('test.hh_a')::uuid, 'child', 7)::text, false);

set local request.jwt.claims to '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';
set local request.jwt.claim.sub to '22222222-2222-4222-8222-222222222222';

-- Migration 12: join-only invites require the joiner's chosen name.
select set_config('test.joined', public.accept_invite(
  current_setting('test.invite'), 'Joiner B')::text, false);

do $$
declare n int;
begin
  if current_setting('test.joined') <> current_setting('test.hh_a') then
    raise exception 'FAIL: accept_invite returned a different household';
  end if;

  -- 4a. Child B now sees the household and its 2 memberships...
  select count(*) into n from public.households;
  if n <> 1 then raise exception 'FAIL: child B sees % households (expected 1)', n; end if;
  select count(*) into n from public.household_users;
  if n <> 2 then raise exception 'FAIL: child B sees % memberships (expected 2)', n; end if;

  -- 4b. ...but sees ONLY the person created for their own join: A's
  --     person and A's transaction stay invisible.
  select count(*) into n from public.members;
  if n <> 1 then raise exception 'FAIL: child B sees % member rows (expected 1)', n; end if;
  select count(*) into n from public.members
   where id = current_setting('test.member_a')::uuid;
  if n <> 0 then raise exception 'FAIL: child B can see A''s person (%)', n; end if;
  select count(*) into n from public.transactions;
  if n <> 0 then raise exception 'FAIL: child B sees % transactions (expected 0)', n; end if;
  -- The name B chose was stored, trimmed, and linked to B's login.
  select count(*) into n from public.members
   where name = 'Joiner B'
     and user_id = '22222222-2222-4222-8222-222222222222';
  if n <> 1 then raise exception 'FAIL: join-only person not stored trimmed+linked (%)', n; end if;

  -- 4c. Child cannot write A's person's transactions.
  begin
    insert into public.transactions (household_id, type, amount, category_id, member_id, date)
    values (current_setting('test.hh_a')::uuid, 'expense', 5,
            current_setting('test.category_a')::uuid,
            current_setting('test.member_a')::uuid, current_date);
    raise exception 'FAIL: child B inserted a transaction for A''s person';
  exception when insufficient_privilege then null;
  end;

  -- 4d. Child cannot edit or delete A's existing transaction.
  update public.transactions
     set amount = 1
   where id = current_setting('test.txn_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child B updated % of A''s transactions', n; end if;

  delete from public.transactions
   where id = current_setting('test.txn_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child B deleted % of A''s transactions', n; end if;

  -- 4e. Child cannot add people, categories or invites.
  begin
    insert into public.members (household_id, name)
    values (current_setting('test.hh_a')::uuid, 'sneaky');
    raise exception 'FAIL: child B inserted a member';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.categories (household_id, "group", name_en, name_ar)
    values (current_setting('test.hh_a')::uuid, 'general', 'X', 'X');
    raise exception 'FAIL: child B inserted a category';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.create_invite(current_setting('test.hh_a')::uuid, 'adult', 1);
    raise exception 'FAIL: child B minted an invite';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  -- 4f. Child cannot promote themselves via household_users UPDATE.
  update public.household_users
     set role = 'adult'
   where user_id = '22222222-2222-4222-8222-222222222222';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child B changed their own role (% rows)', n; end if;
end $$;

-- --------------------------------------------------------------------
-- 5. PHASE 2: person-bound invite -> auto-link, and the child
--    restrictions that depend on members.user_id.
-- --------------------------------------------------------------------
-- Back to superuser to seed the extra throw-away logins.
set local role none;

-- Logins: C (the linked child), D + E (edge-case acceptors).
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-4333-8333-333333333333',
   'authenticated', 'authenticated', 'rls-test-c@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-8444-444444444444',
   'authenticated', 'authenticated', 'rls-test-d@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '55555555-5555-4555-8555-555555555555',
   'authenticated', 'authenticated', 'rls-test-e@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;

-- 5.0 Setup as USER A: a person to bind, a budget, a bound invite,
--     and one transaction already recorded for that person.
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

insert into public.members (household_id, name)
values (current_setting('test.hh_a')::uuid, 'Linked Kid');

select set_config('test.member_kid', (
  select m.id from public.members m
  where m.household_id = current_setting('test.hh_a')::uuid
    and m.name = 'Linked Kid'
  limit 1)::text, false);

insert into public.budgets (household_id, category_id, amount, period)
values (current_setting('test.hh_a')::uuid,
        current_setting('test.category_a')::uuid, 500.00, 'monthly');

select set_config('test.budget_a', (
  select b.id from public.budgets b
  where b.household_id = current_setting('test.hh_a')::uuid
  limit 1)::text, false);

select set_config('test.invite_link', public.create_invite(
  current_setting('test.hh_a')::uuid, 'child', 7,
  current_setting('test.member_kid')::uuid)::text, false);

-- A records a transaction for the Linked Kid BEFORE the kid logs in.
insert into public.transactions (household_id, type, amount, category_id, member_id, date, created_by)
values (current_setting('test.hh_a')::uuid, 'expense', 12.00,
        current_setting('test.category_a')::uuid,
        current_setting('test.member_kid')::uuid, current_date, auth.uid());

select set_config('test.txn_kid', (
  select t.id from public.transactions t
  where t.member_id = current_setting('test.member_kid')::uuid
  limit 1)::text, false);

-- 5.1 USER C accepts the person-bound invite -> members.user_id = C.
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

select set_config('test.joined_c', public.accept_invite(
  current_setting('test.invite_link'))::text, false);

do $$
declare n int;
begin
  if current_setting('test.joined_c') <> current_setting('test.hh_a') then
    raise exception 'FAIL: bound invite joined a different household';
  end if;

  -- Auto-link proof: the person row now points at C's login.
  select count(*) into n from public.members m
   where m.id = current_setting('test.member_kid')::uuid
     and m.user_id = '33333333-3333-4333-8333-333333333333';
  if n <> 1 then raise exception 'FAIL: accept_invite did not set members.user_id (got % rows)', n; end if;

  -- Role came from the invite.
  select count(*) into n from public.household_users
   where user_id = '33333333-3333-4333-8333-333333333333' and role = 'child';
  if n <> 1 then raise exception 'FAIL: linked child has wrong role (% rows)', n; end if;

  -- C sees exactly ONE person: their own linked row (A Person stays hidden).
  select count(*) into n from public.members;
  if n <> 1 then raise exception 'FAIL: linked child sees % member rows (expected 1)', n; end if;

  -- C sees exactly ONE transaction: the one for their own person
  -- (txn_a for A Person stays invisible).
  select count(*) into n from public.transactions;
  if n <> 1 then raise exception 'FAIL: linked child sees % transactions (expected 1)', n; end if;

  -- SELECT isolation: A's transaction is invisible even by id.
  update public.transactions
     set amount = 1
   where id = current_setting('test.txn_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child edited A''s transaction (% rows)', n; end if;

  -- 5.2 INSERT: own member = allowed, other person = denied.
  insert into public.transactions (household_id, type, amount, category_id, member_id, date)
  values (current_setting('test.hh_a')::uuid, 'expense', 4.75,
          current_setting('test.category_a')::uuid,
          current_setting('test.member_kid')::uuid, current_date);

  select count(*) into n from public.transactions;
  if n <> 2 then raise exception 'FAIL: child sees % transactions after own insert (expected 2)', n; end if;

  begin
    insert into public.transactions (household_id, type, amount, category_id, member_id, date)
    values (current_setting('test.hh_a')::uuid, 'expense', 1,
            current_setting('test.category_a')::uuid,
            current_setting('test.member_a')::uuid, current_date);
    raise exception 'FAIL: child inserted a transaction for another person';
  exception when insufficient_privilege then null;
  end;

  -- 5.3 Child cannot EDIT categories (read-only for children).
  update public.categories
     set name_en = 'pwned'
   where id = current_setting('test.category_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child edited a category (% rows)', n; end if;

  delete from public.categories
   where id = current_setting('test.category_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child deleted a category (% rows)', n; end if;

  begin
    insert into public.categories (household_id, "group", name_en, name_ar)
    values (current_setting('test.hh_a')::uuid, 'general', 'Kid Category', ' Kid');
    raise exception 'FAIL: child inserted a category';
  exception when insufficient_privilege then null;
  end;

  -- 5.4 Child cannot EDIT members - not even their OWN row. After
  --     migration 12 a direct name write is rejected outright (column
  --     grant); renames only go through rename_member().
  begin
    update public.members
       set name = 'renamed by kid'
     where household_id = current_setting('test.hh_a')::uuid;
    raise exception 'FAIL: child renamed a member directly';
  exception when insufficient_privilege then null;
  end;

  delete from public.members
   where household_id = current_setting('test.hh_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child deleted % member rows', n; end if;

  -- 5.5 Child cannot EDIT budgets (may read them, never write).
  update public.budgets
     set amount = 1
   where id = current_setting('test.budget_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child edited a budget (% rows)', n; end if;

  delete from public.budgets
   where id = current_setting('test.budget_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child deleted a budget (% rows)', n; end if;

  begin
    insert into public.budgets (household_id, category_id, amount, period)
    values (current_setting('test.hh_a')::uuid,
            current_setting('test.category_a')::uuid, 1.00, 'monthly');
    raise exception 'FAIL: child inserted a budget';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 5.6 Edge case at CREATE time: binding an already-linked person fails.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
begin
  begin
    perform public.create_invite(
      current_setting('test.hh_a')::uuid, 'child', 7,
      current_setting('test.member_kid')::uuid);
    raise exception 'FAIL: create_invite bound a person who is already linked';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'member_linked' then raise; end if;
  end;
end $$;

-- 5.7 Edge case at ACCEPT time: two codes minted for the same still-
--     unlinked person; the second acceptance must fail with
--     already_linked (migration 12's distinct accept-time key) and must
--     NOT consume the code or create a membership.
insert into public.members (household_id, name)
values (current_setting('test.hh_a')::uuid, 'Kid D');

select set_config('test.member_d', (
  select m.id from public.members m
  where m.household_id = current_setting('test.hh_a')::uuid and m.name = 'Kid D'
  limit 1)::text, false);

select set_config('test.invite_d1', public.create_invite(
  current_setting('test.hh_a')::uuid, 'child', 7,
  current_setting('test.member_d')::uuid)::text, false);
select set_config('test.invite_d2', public.create_invite(
  current_setting('test.hh_a')::uuid, 'child', 7,
  current_setting('test.member_d')::uuid)::text, false);

set local request.jwt.claims to '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated"}';
set local request.jwt.claim.sub to '44444444-4444-4444-8444-444444444444';

select set_config('test.joined_d', public.accept_invite(
  current_setting('test.invite_d1'))::text, false);

set local request.jwt.claims to '{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated"}';
set local request.jwt.claim.sub to '55555555-5555-4555-8555-555555555555';

do $$
begin
  begin
    perform public.accept_invite(current_setting('test.invite_d2'));
    raise exception 'FAIL: second acceptance linked a person who was already linked';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'already_linked' then raise; end if;
  end;
end $$;

-- 5.8 USER A (owner) still sees the whole household: the child
--     restrictions above must NOT have narrowed the owner's view.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare n int;
begin
  -- A Person (owner, auto-created), Joiner B, Linked Kid, Kid D.
  select count(*) into n from public.members;
  if n <> 4 then raise exception 'FAIL: owner sees % members (expected 4)', n; end if;
  -- txn_a + pre-linked kid txn + C's own insert
  select count(*) into n from public.transactions;
  if n <> 3 then raise exception 'FAIL: owner sees % transactions (expected 3)', n; end if;
  select count(*) into n from public.budgets;
  if n <> 1 then raise exception 'FAIL: owner sees % budgets (expected 1)', n; end if;
  select count(*) into n from public.categories;
  if n <> 31 then raise exception 'FAIL: owner sees % categories (expected 31)', n; end if;
  -- Both bound codes exist; the failed acceptance consumed neither usage.
  select count(*) into n from public.invites where used_by is not null;
  if n <> 3 then raise exception 'FAIL: owner sees % used invites (expected 3: plain, C, D1)', n; end if;
end $$;

-- --------------------------------------------------------------------
-- 6. PHASE 2.5: self-service membership - join-only names, claim_member,
--    rename/role/leave/remove RPCs, direct-write lockdown.
-- --------------------------------------------------------------------
set local role none;

-- Logins: F (join-only joiner), G (legacy login with a household but
-- no person), H (no household at all), J + K + L (the role / leave /
-- remove cast in their own household).
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', '66666666-6666-4666-8666-666666666666',
   'authenticated', 'authenticated', 'rls-test-f@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '77777777-7777-4777-8777-777777777777',
   'authenticated', 'authenticated', 'rls-test-g@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '88888888-8888-4888-8888-888888888888',
   'authenticated', 'authenticated', 'rls-test-h@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '99999999-9999-4999-8999-999999999999',
   'authenticated', 'authenticated', 'rls-test-j@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'authenticated', 'authenticated', 'rls-test-k@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'authenticated', 'authenticated', 'rls-test-l@test.local', 'not-a-real-hash',
   now(), '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;

-- 6.1 Join-only invite: the joiner CHOOSES their name, and a bad name
--     never consumes the code.
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

select set_config('test.invite_join', public.create_invite(
  current_setting('test.hh_a')::uuid, 'child', 7)::text, false);

set local request.jwt.claims to '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}';
set local request.jwt.claim.sub to '66666666-6666-4666-8666-666666666666';

do $$
declare n int;
begin
  begin
    perform public.accept_invite(current_setting('test.invite_join'), '   ');
    raise exception 'FAIL: blank display name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  begin
    perform public.accept_invite(current_setting('test.invite_join'), repeat('x', 41));
    raise exception 'FAIL: 41-char display name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  -- Both failures wrote nothing: no membership, code still unused.
  select count(*) into n from public.household_users
   where user_id = '66666666-6666-4666-8666-666666666666';
  if n <> 0 then raise exception 'FAIL: failed accepts wrote a membership (%)', n; end if;
end $$;

select set_config('test.joined_f', public.accept_invite(
  current_setting('test.invite_join'), '   Fayzah Al-Sayed   ')::text, false);

do $$
declare n int;
begin
  if current_setting('test.joined_f') <> current_setting('test.hh_a') then
    raise exception 'FAIL: join-only accept joined a different household';
  end if;
  -- Stored trimmed, exactly once, linked to F's login, invite role applied.
  select count(*) into n from public.members
   where user_id = '66666666-6666-4666-8666-666666666666'
     and name = 'Fayzah Al-Sayed';
  if n <> 1 then raise exception 'FAIL: join-only person not stored trimmed+linked (got %)', n; end if;
  select count(*) into n from public.household_users
   where user_id = '66666666-6666-4666-8666-666666666666' and role = 'child';
  if n <> 1 then raise exception 'FAIL: join-only joiner has wrong role (%)', n; end if;
end $$;

-- 6.2 claim_member: G is a LEGACY login (household, person = none).
set local role none;
insert into public.household_users (household_id, user_id, role)
values (current_setting('test.hh_a')::uuid, '77777777-7777-4777-8777-777777777777', 'adult')
on conflict (household_id, user_id) do nothing;

set local role authenticated;
set local request.jwt.claims to '{"sub":"77777777-7777-4777-8777-777777777777","role":"authenticated"}';
set local request.jwt.claim.sub to '77777777-7777-4777-8777-777777777777';

do $$
declare n int; v_id uuid;
begin
  select count(*) into n from public.members
   where user_id = '77777777-7777-4777-8777-777777777777';
  if n <> 0 then raise exception 'TEST SETUP FAILED: G starts with a person (%)', n; end if;

  begin
    perform public.claim_member('');
    raise exception 'FAIL: claim_member accepted an empty name';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  v_id := public.claim_member('  G Person  ');
  select count(*) into n from public.members
   where id = v_id
     and user_id = '77777777-7777-4777-8777-777777777777'
     and name = 'G Person';
  if n <> 1 then raise exception 'FAIL: claim_member did not create+link+trim (got %)', n; end if;

  begin
    perform public.claim_member('Again');
    raise exception 'FAIL: second claim_member created a duplicate person';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'member_linked' then raise; end if;
  end;
end $$;

-- H has no household at all -> claim is meaningless for them.
set local request.jwt.claims to '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated"}';
set local request.jwt.claim.sub to '88888888-8888-4888-8888-888888888888';

do $$
begin
  begin
    perform public.claim_member('Nobody');
    raise exception 'FAIL: claim_member worked for a login with no household';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'not_member' then raise; end if;
  end;
end $$;

-- 6.3 rename_member matrix. First: J creates their own household.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

select set_config('test.hh_j', public.create_household('Test HH J', 'JOD', 'J Person')::text, false);

select set_config('test.member_j', (
  select m.id from public.members m
  where m.household_id = current_setting('test.hh_j')::uuid and m.name = 'J Person'
  limit 1)::text, false);

-- F (child of hh_a) may rename ONLY their own person.
set local request.jwt.claims to '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}';
set local request.jwt.claim.sub to '66666666-6666-4666-8666-666666666666';

do $$
declare n int; v_me uuid;
begin
  select m.id into v_me from public.members m
   where m.user_id = '66666666-6666-4666-8666-666666666666';

  perform public.rename_member(v_me, '  Little F  ');
  select count(*) into n from public.members where id = v_me and name = 'Little F';
  if n <> 1 then raise exception 'FAIL: self-rename did not store a trimmed name (%)', n; end if;

  begin
    perform public.rename_member(current_setting('test.member_a')::uuid, 'Pwned A');
    raise exception 'FAIL: child renamed another person';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.rename_member(current_setting('test.member_j')::uuid, 'Pwned J');
    raise exception 'FAIL: renamed a person of ANOTHER household';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_member' then raise; end if;
  end;

  begin
    perform public.rename_member(v_me, '');
    raise exception 'FAIL: rename_member accepted an empty name';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;
end $$;

-- A (owner of hh_a) may rename ANY person of their household.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare n int;
begin
  perform public.rename_member(
    (select m.id from public.members m
      where m.user_id = '77777777-7777-4777-8777-777777777777'),
    'G renamed');
  select count(*) into n from public.members
   where user_id = '77777777-7777-4777-8777-777777777777' and name = 'G renamed';
  if n <> 1 then raise exception 'FAIL: owner could not rename another person (%)', n; end if;

  -- A renaming a person of ANOTHER household must fail too.
  begin
    perform public.rename_member(current_setting('test.member_j')::uuid, 'Pwned J');
    raise exception 'FAIL: owner renamed a person of another household';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_member' then raise; end if;
  end;
end $$;

-- 6.4 update_household_role matrix in hh_j (K + L start as adults
--     without persons of their own).
set local role none;
insert into public.household_users (household_id, user_id, role) values
  (current_setting('test.hh_j')::uuid, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'adult'),
  (current_setting('test.hh_j')::uuid, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'adult')
on conflict (household_id, user_id) do nothing;

set local role authenticated;
set local request.jwt.claims to '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
set local request.jwt.claim.sub to 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

do $$
begin
  -- K (adult, NOT owner) cannot touch roles at all.
  begin
    perform public.update_household_role(current_setting('test.hh_j')::uuid,
      '99999999-9999-4999-8999-999999999999', 'adult');
    raise exception 'FAIL: non-owner changed a role';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  -- K (non-owner) cannot remove logins either.
  begin
    perform public.remove_household_login(current_setting('test.hh_j')::uuid,
      '99999999-9999-4999-8999-999999999999');
    raise exception 'FAIL: non-owner removed a login';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;
end $$;

-- J (owner) walks the whole role matrix.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
declare n int;
begin
  -- Role 'child' requires the target login to have a linked person.
  begin
    perform public.update_household_role(current_setting('test.hh_j')::uuid,
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'child');
    raise exception 'FAIL: child role set on a login with no person';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'child_requires_member' then raise; end if;
  end;

  -- Promotion TO owner is allowed (ownership-transfer path).
  perform public.update_household_role(current_setting('test.hh_j')::uuid,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'owner');
  select count(*) into n from public.household_users
   where household_id = current_setting('test.hh_j')::uuid
     and user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
     and role = 'owner';
  if n <> 1 then raise exception 'FAIL: promotion to owner did not stick (%)', n; end if;

  -- With TWO owners, demoting yourself -> cannot_change_own_role
  -- (last_owner correctly does NOT fire first here).
  begin
    perform public.update_household_role(current_setting('test.hh_j')::uuid,
      '99999999-9999-4999-8999-999999999999', 'adult');
    raise exception 'FAIL: owner changed their own role';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'cannot_change_own_role' then raise; end if;
  end;

  -- Invalid role names are rejected.
  begin
    perform public.update_household_role(current_setting('test.hh_j')::uuid,
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'supermaster');
    raise exception 'FAIL: invalid role name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_role' then raise; end if;
  end;

  -- A login of ANOTHER household is simply not a member here.
  begin
    perform public.update_household_role(current_setting('test.hh_j')::uuid,
      '66666666-6666-4666-8666-666666666666', 'adult');
    raise exception 'FAIL: role set on a login of another household';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_member' then raise; end if;
  end;
end $$;

-- K (now also an owner): demote J, then hit last_owner on SELF.
set local request.jwt.claims to '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
set local request.jwt.claim.sub to 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

do $$
declare n int;
begin
  perform public.update_household_role(current_setting('test.hh_j')::uuid,
    '99999999-9999-4999-8999-999999999999', 'adult');
  select count(*) into n from public.household_users
   where household_id = current_setting('test.hh_j')::uuid
     and user_id = '99999999-9999-4999-8999-999999999999'
     and role = 'adult';
  if n <> 1 then raise exception 'FAIL: peer-owner demotion did not stick (%)', n; end if;

  -- Sole owner demoting THEMSELVES must get last_owner - this proves
  -- the last-owner check runs BEFORE the cannot_change_own_role check.
  begin
    perform public.update_household_role(current_setting('test.hh_j')::uuid,
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'adult');
    raise exception 'FAIL: sole owner demoted themselves';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'last_owner' then raise; end if;
  end;

  -- Restore: K promotes J back to owner.
  perform public.update_household_role(current_setting('test.hh_j')::uuid,
    '99999999-9999-4999-8999-999999999999', 'owner');
end $$;

-- 6.5 leave_household / remove_household_login.
-- L claims a person first, then becomes a child.
set local request.jwt.claims to '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';
set local request.jwt.claim.sub to 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

do $$
declare n int; v_cat uuid;
begin
  perform public.claim_member('L Person');
  select count(*) into n from public.members
   where user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' and name = 'L Person';
  if n <> 1 then raise exception 'FAIL: L could not claim a person (%)', n; end if;
end $$;

-- J (owner) now succeeds where child_requires_member fired before.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
begin
  perform public.update_household_role(current_setting('test.hh_j')::uuid,
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'child');
end $$;

-- L (now a linked child) records a transaction for their own person.
set local request.jwt.claims to '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';
set local request.jwt.claim.sub to 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

do $$
declare v_cat uuid;
begin
  select c.id into v_cat from public.categories c
   where c.household_id = current_setting('test.hh_j')::uuid
     and c."group" = 'general'
   limit 1;

  insert into public.transactions (household_id, type, amount, category_id, member_id, date)
  values (current_setting('test.hh_j')::uuid, 'expense', 3.50, v_cat,
          (select m.id from public.members m
            where m.user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
          current_date);
end $$;

-- L leaves: membership gone, link cleared, person + transaction kept.
do $$
begin
  perform public.leave_household();
end $$;

set local role none;

do $$
declare n int;
begin
  select count(*) into n from public.household_users
   where household_id = current_setting('test.hh_j')::uuid
     and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  if n <> 0 then raise exception 'FAIL: leaver still has a membership (%)', n; end if;

  select count(*) into n from public.members
   where household_id = current_setting('test.hh_j')::uuid
     and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  if n <> 0 then raise exception 'FAIL: leaver''s person still linked (%)', n; end if;

  select count(*) into n from public.members where name = 'L Person';
  if n <> 1 then raise exception 'FAIL: leaver''s person was deleted (%)', n; end if;

  select count(*) into n from public.transactions t
   join public.members m on m.id = t.member_id
   where m.name = 'L Person';
  if n <> 1 then raise exception 'FAIL: leaver''s transactions were deleted (%)', n; end if;
end $$;

-- The removed login LOST every trace of the household immediately.
set local role authenticated;
set local request.jwt.claims to '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';
set local request.jwt.claim.sub to 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

do $$
declare n int;
begin
  select count(*) into n from public.households;
  if n <> 0 then raise exception 'FAIL: removed login sees % households (expected 0)', n; end if;
  select count(*) into n from public.household_users;
  if n <> 0 then raise exception 'FAIL: removed login sees % memberships (expected 0)', n; end if;
  select count(*) into n from public.members;
  if n <> 0 then raise exception 'FAIL: removed login sees % persons (expected 0)', n; end if;
  select count(*) into n from public.transactions;
  if n <> 0 then raise exception 'FAIL: removed login sees % transactions (expected 0)', n; end if;
  select count(*) into n from public.invites;
  if n <> 0 then raise exception 'FAIL: removed login sees % invites (expected 0)', n; end if;

  begin
    perform public.create_invite(current_setting('test.hh_j')::uuid, 'adult', 1);
    raise exception 'FAIL: removed login minted an invite';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'not_member' then raise; end if;
  end;
end $$;

-- K claims a person and records a transaction, so removal can prove
-- the same keep-transactions semantics.
set local request.jwt.claims to '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
set local request.jwt.claim.sub to 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

do $$
declare v_cat uuid;
begin
  perform public.claim_member('K Person');
  select c.id into v_cat from public.categories c
   where c.household_id = current_setting('test.hh_j')::uuid
     and c."group" = 'general'
   limit 1;
  insert into public.transactions (household_id, type, amount, category_id, member_id, date)
  values (current_setting('test.hh_j')::uuid, 'expense', 7.25, v_cat,
          (select m.id from public.members m
            where m.user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
          current_date);
end $$;

-- J cannot remove THEMSELVES (must use leave instead).
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
begin
  begin
    perform public.remove_household_login(current_setting('test.hh_j')::uuid,
      '99999999-9999-4999-8999-999999999999');
    raise exception 'FAIL: owner removed themselves via remove_household_login';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'cannot_remove_self' then raise; end if;
  end;
end $$;

-- J (owner) removes K: link cleared, person + transactions kept.
do $$
begin
  perform public.remove_household_login(current_setting('test.hh_j')::uuid,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
end $$;

set local role none;

do $$
declare n int;
begin
  select count(*) into n from public.household_users
   where household_id = current_setting('test.hh_j')::uuid
     and user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  if n <> 0 then raise exception 'FAIL: removed login still has a membership (%)', n; end if;
  select count(*) into n from public.members
   where name = 'K Person' and user_id is null;
  if n <> 1 then raise exception 'FAIL: removed login''s person not unlinked (%)', n; end if;
  select count(*) into n from public.transactions t
   join public.members m on m.id = t.member_id
   where m.name = 'K Person';
  if n <> 1 then raise exception 'FAIL: removed login''s transactions were deleted (%)', n; end if;
end $$;

-- K lost every trace of hh_j immediately.
set local role authenticated;
set local request.jwt.claims to '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
set local request.jwt.claim.sub to 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

do $$
declare n int;
begin
  select count(*) into n from public.households;
  if n <> 0 then raise exception 'FAIL: removed login K sees % households (expected 0)', n; end if;
  select count(*) into n from public.household_users;
  if n <> 0 then raise exception 'FAIL: removed login K sees % memberships (expected 0)', n; end if;
  select count(*) into n from public.members;
  if n <> 0 then raise exception 'FAIL: removed login K sees % persons (expected 0)', n; end if;
  select count(*) into n from public.transactions;
  if n <> 0 then raise exception 'FAIL: removed login K sees % transactions (expected 0)', n; end if;
  select count(*) into n from public.invites;
  if n <> 0 then raise exception 'FAIL: removed login K sees % invites (expected 0)', n; end if;

  begin
    perform public.create_invite(current_setting('test.hh_j')::uuid, 'adult', 1);
    raise exception 'FAIL: removed login K minted an invite';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'not_member' then raise; end if;
  end;
end $$;

-- J is now the SOLE owner -> leaving must fail with last_owner.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
begin
  begin
    perform public.leave_household();
    raise exception 'FAIL: the sole owner left the household';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'last_owner' then raise; end if;
  end;
end $$;

-- 6.6 Direct-write lockdown on members (as owner A).
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare n int;
begin
  -- A direct INSERT can never attach a login to a person.
  begin
    insert into public.members (household_id, name, user_id)
    values (current_setting('test.hh_a')::uuid, 'Self Attached', auth.uid());
    raise exception 'FAIL: direct insert attached a login to a person';
  exception when insufficient_privilege then null;
  end;

  -- Names and links are not directly writable AT ALL anymore.
  begin
    update public.members set name = 'direct rename'
     where id = current_setting('test.member_a')::uuid;
    raise exception 'FAIL: owner renamed a person directly';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.members set user_id = null
     where id = current_setting('test.member_a')::uuid;
    raise exception 'FAIL: owner rewrote a person''s link directly';
  exception when insufficient_privilege then null;
  end;

  -- Linked persons cannot be deleted directly...
  delete from public.members
   where id = current_setting('test.member_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: owner deleted a LINKED person (% rows)', n; end if;

  -- ...but the add-person flow (unlinked INSERT) still works, and the
  -- name trigger trims + validates on the way in.
  begin
    insert into public.members (household_id, name)
    values (current_setting('test.hh_a')::uuid, '   ');
    raise exception 'FAIL: blank person name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  begin
    insert into public.members (household_id, name)
    values (current_setting('test.hh_a')::uuid, repeat('y', 41));
    raise exception 'FAIL: 41-char person name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  insert into public.members (household_id, name)
  values (current_setting('test.hh_a')::uuid, '   Spare Person  ');
  select count(*) into n from public.members
   where name = 'Spare Person' and user_id is null;
  if n <> 1 then raise exception 'FAIL: name trigger did not trim a direct insert (%)', n; end if;

  -- is_active stays directly writable (deactivate flow).
  update public.members set is_active = false where name = 'Spare Person';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL: deactivate update touched % rows', n; end if;

  -- Unlinked persons can still be deleted (remove-person flow).
  delete from public.members where name = 'Spare Person';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL: unlinked person delete touched % rows', n; end if;

  -- Roles have no direct table path at all anymore (RPC only).
  update public.household_users set role = 'owner'
   where household_id = current_setting('test.hh_a')::uuid
     and user_id = '66666666-6666-4666-8666-666666666666';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: role changed directly (% rows)', n; end if;
end $$;

-- 6.7 accept_invite edge cases: login_linked and a person of ANOTHER
--     household (invalid_member). Both must leave the code unconsumed.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

insert into public.members (household_id, name)
values (current_setting('test.hh_a')::uuid, 'To Link');

select set_config('test.member_to_link', (
  select m.id from public.members m
  where m.household_id = current_setting('test.hh_a')::uuid and m.name = 'To Link'
  limit 1)::text, false);

select set_config('test.invite_bound', public.create_invite(
  current_setting('test.hh_a')::uuid, 'adult', 7,
  current_setting('test.member_to_link')::uuid)::text, false);

-- Simulate a login whose person exists but whose membership was lost:
-- accepting a person-bound invite must refuse (login_linked).
set local role none;
delete from public.household_users
 where household_id = current_setting('test.hh_a')::uuid
   and user_id = '66666666-6666-4666-8666-666666666666';

set local role authenticated;
set local request.jwt.claims to '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated"}';
set local request.jwt.claim.sub to '66666666-6666-4666-8666-666666666666';

do $$
begin
  begin
    perform public.accept_invite(current_setting('test.invite_bound'));
    raise exception 'FAIL: a login that already has a person linked accepted a bound invite';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'login_linked' then raise; end if;
  end;
end $$;

-- Corrupt the invite (defence-in-depth probe): point it at a person of
-- ANOTHER household. H must be rejected with invalid_member.
set local role none;
update public.invites
   set member_id = current_setting('test.member_j')::uuid
 where code = current_setting('test.invite_bound');

set local role authenticated;
set local request.jwt.claims to '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated"}';
set local request.jwt.claim.sub to '88888888-8888-4888-8888-888888888888';

do $$
declare n int;
begin
  begin
    perform public.accept_invite(current_setting('test.invite_bound'), 'H Name');
    raise exception 'FAIL: accepted a bound invite pointing at a foreign person';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_member' then raise; end if;
  end;

  select count(*) into n from public.household_users
   where user_id = '88888888-8888-4888-8888-888888888888';
  if n <> 0 then raise exception 'FAIL: failed accepts wrote a membership (%)', n; end if;
end $$;

-- Neither failure consumed the code.
set local role none;
do $$
declare n int;
begin
  select count(*) into n from public.invites
   where code = current_setting('test.invite_bound') and used_by is null;
  if n <> 1 then raise exception 'FAIL: failed accepts consumed the code (%)', n; end if;
end $$;

-- --------------------------------------------------------------------
-- 8. PHASE 3: vehicles, fuel log, maintenance reminders, recurring
--    generation (owner/adult only; children + outsiders locked out).
-- --------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- 8.0 Owner A seeds two vehicles (petrol + electric) by direct insert.
do $$
declare v_car uuid; v_ev uuid;
begin
  insert into public.vehicles (household_id, name, plate, fuel_type)
  values (current_setting('test.hh_a')::uuid, 'A Car', 'ABC-123', 'petrol')
  returning id into v_car;
  perform set_config('test.vehicle_a', v_car::text, false);

  insert into public.vehicles (household_id, name, plate, fuel_type)
  values (current_setting('test.hh_a')::uuid, 'A EV', null, 'electric')
  returning id into v_ev;
  perform set_config('test.vehicle_ev', v_ev::text, false);
end $$;

-- 8.1 add_fuel_log creates the log, bumps the odometer, and inserts the
--     single linked car expense (no double counting).
do $$
declare v_tx uuid; v_log uuid;
begin
  v_log := public.add_fuel_log(
    current_setting('test.vehicle_a')::uuid, current_date - 2, 10000, 45.350, 10050, true);
  perform set_config('test.fuel1', v_log::text, false);

  select transaction_id into v_tx from public.fuel_logs where id = v_log;
  perform set_config('test.txn_fuel1', v_tx::text, false);

  perform public.add_fuel_log(
    current_setting('test.vehicle_a')::uuid, current_date - 1, 10300, 42.750, 9500, true);

  -- Electric: no liters allowed/needed; cost still recorded.
  perform public.add_fuel_log(
    current_setting('test.vehicle_ev')::uuid, current_date, 500, 0, 3000, true);
end $$;

do $$
declare n int; v numeric;
begin
  select count(*) into n from public.fuel_logs;
  if n <> 3 then raise exception 'FAIL: owner sees % fuel logs (expected 3)', n; end if;

  select current_odometer into v from public.vehicles
   where id = current_setting('test.vehicle_a')::uuid;
  if v <> 10300 then raise exception 'FAIL: vehicle odometer not bumped (got %)', v; end if;
  select current_odometer into v from public.vehicles
   where id = current_setting('test.vehicle_ev')::uuid;
  if v <> 500 then raise exception 'FAIL: electric odometer not set (got %)', v; end if;

  select count(*) into n
    from public.transactions t
    join public.categories c on c.id = t.category_id
   where t.id = current_setting('test.txn_fuel1')::uuid
     and t.type = 'expense'
     and t.amount = 100.50
     and t.vehicle_id = current_setting('test.vehicle_a')::uuid
     and t.member_id = current_setting('test.member_a')::uuid
     and c."group" = 'car'
     and c.name_en = 'Fuel'
     and t.odometer = 10000
     and t.liters = 45.350
     and t.note = 'A Car';
  if n <> 1 then raise exception 'FAIL: fuel expense row wrong (% rows)', n; end if;

  select count(*) into n from public.transactions
   where vehicle_id = current_setting('test.vehicle_a')::uuid;
  if n <> 2 then raise exception 'FAIL: expected 2 car expenses from 2 fill-ups (got %)', n; end if;
end $$;

-- 8.2 Rejected fuel inputs leave nothing behind.
do $$
declare n int;
begin
  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      current_date, 10250, 40, 9000, false);
    raise exception 'FAIL: backwards odometer accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'odometer_backwards' then raise; end if;
  end;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      current_date, 10400, 0, 9000, false);
    raise exception 'FAIL: zero liters accepted on petrol';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      current_date, -1, 40, 9000, false);
    raise exception 'FAIL: negative odometer accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      current_date, 10400, 40, 0, false);
    raise exception 'FAIL: zero cost accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      null, 10400, 40, 9000, false);
    raise exception 'FAIL: null date accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_ev')::uuid,
      current_date, 600, 5, 3000, true);
    raise exception 'FAIL: liters accepted on electric';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  select count(*) into n from public.fuel_logs;
  if n <> 3 then raise exception 'FAIL: invalid fuel attempts wrote rows (% logs)', n; end if;
end $$;

-- 8.3 Maintenance reminders: create, name trigger, complete + re-arm.
do $$
declare v1 uuid; v2 uuid;
begin
  insert into public.maintenance_items (household_id, vehicle_id, name, due_date, interval_days)
  values (current_setting('test.hh_a')::uuid, current_setting('test.vehicle_a')::uuid,
          'Oil Change', current_date - 1, 180)
  returning id into v1;
  perform set_config('test.item1', v1::text, false);

  insert into public.maintenance_items (household_id, vehicle_id, name, due_odometer_km, interval_km)
  values (current_setting('test.hh_a')::uuid, current_setting('test.vehicle_a')::uuid,
          'Tires', 9900, 5000)
  returning id into v2;
  perform set_config('test.item2', v2::text, false);
end $$;

do $$
declare n int; v_due date; v_odo numeric;
begin
  begin
    insert into public.maintenance_items (household_id, vehicle_id, name, due_date)
    values (current_setting('test.hh_a')::uuid, current_setting('test.vehicle_a')::uuid,
            '   ', current_date);
    raise exception 'FAIL: blank maintenance name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  perform public.complete_maintenance(current_setting('test.item1')::uuid, 20000, 'At Garage');
  select due_date into v_due from public.maintenance_items
   where id = current_setting('test.item1')::uuid;
  if v_due <> (current_date - 1) + 180 then
    raise exception 'FAIL: day-interval re-arm wrong (got %)', v_due;
  end if;
  select count(*) into n from public.maintenance_items
   where id = current_setting('test.item1')::uuid and completed_at is not null;
  if n <> 1 then raise exception 'FAIL: item not marked complete'; end if;

  select count(*) into n from public.transactions
   where vehicle_id = current_setting('test.vehicle_a')::uuid
     and amount = 200.00 and note = 'At Garage'
     and member_id = current_setting('test.member_a')::uuid;
  if n <> 1 then raise exception 'FAIL: maintenance expense wrong (%)', n; end if;

  perform public.complete_maintenance(current_setting('test.item2')::uuid);
  select due_odometer_km into v_odo from public.maintenance_items
   where id = current_setting('test.item2')::uuid;
  if v_odo <> 14900 then raise exception 'FAIL: km-interval re-arm wrong (got %)', v_odo; end if;

  begin
    perform public.complete_maintenance('00000000-0000-0000-0000-000000000000');
    raise exception 'FAIL: completing an unknown item succeeded';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_item' then raise; end if;
  end;
end $$;

-- 8.4 Recurring generation: idempotent, respects end_date, derives type
--     from the category group, and children trigger nothing.
select set_config('test.category_income', (
  select c.id from public.categories c
  where c.household_id = current_setting('test.hh_a')::uuid and c."group" = 'income'
  order by c.name_en limit 1)::text, false);

do $$
declare r1 uuid; r2 uuid; r3 uuid;
begin
  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, next_due, name)
  values (current_setting('test.hh_a')::uuid, current_setting('test.category_a')::uuid,
          current_setting('test.member_a')::uuid, 2000.00, 'weekly', current_date - 40, 'Rent')
  returning id into r1;
  perform set_config('test.rule1', r1::text, false);

  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, next_due, name)
  values (current_setting('test.hh_a')::uuid, current_setting('test.category_income')::uuid,
          current_setting('test.member_a')::uuid, 5000.00, 'monthly', current_date - 3, 'Salary')
  returning id into r2;
  perform set_config('test.rule2', r2::text, false);

  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, next_due, end_date, name)
  values (current_setting('test.hh_a')::uuid, current_setting('test.category_a')::uuid,
          current_setting('test.member_a')::uuid, 100.00, 'weekly', current_date - 20,
          current_date - 7, 'Temp')
  returning id into r3;
  perform set_config('test.rule3', r3::text, false);
end $$;

-- Child C runs the generator FIRST: returns 0 (children never generate).
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

select set_config('test.child_created', public.generate_recurring_transactions()::text, false);

do $$
begin
  if current_setting('test.child_created') <> '0' then
    raise exception 'FAIL: child generated % recurring transactions (expected 0)',
      current_setting('test.child_created');
  end if;
end $$;

-- Owner A runs it: 6 (weekly x40d) + 1 (monthly) + 2 (weekly, end_date) = 9.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

select set_config('test.created', public.generate_recurring_transactions()::text, false);

do $$
declare n int; v_due date;
begin
  if current_setting('test.created') <> '9' then
    raise exception 'FAIL: generator created % rows (expected 9)', current_setting('test.created');
  end if;

  select count(*) into n from public.transactions
   where recurring_rule_id = current_setting('test.rule1')::uuid;
  if n <> 6 then raise exception 'FAIL: weekly rule produced % rows (expected 6)', n; end if;

  select count(*) into n from public.transactions
   where recurring_rule_id = current_setting('test.rule2')::uuid and type = 'income';
  if n <> 1 then raise exception 'FAIL: income rule produced % income rows (expected 1)', n; end if;

  select count(*) into n from public.transactions
   where recurring_rule_id = current_setting('test.rule3')::uuid;
  if n <> 2 then raise exception 'FAIL: end_date rule produced % rows (expected 2)', n; end if;

  -- Cursor moved past the last generated date (no re-scan next time).
  select next_due into v_due from public.recurring_rules
   where id = current_setting('test.rule1')::uuid;
  if v_due <> current_date + 2 then
    raise exception 'FAIL: weekly cursor not advanced (got %)', v_due;
  end if;
end $$;

-- Second run is a no-op (idempotent via the partial unique index).
select set_config('test.created2', public.generate_recurring_transactions()::text, false);

do $$
begin
  if current_setting('test.created2') <> '0' then
    raise exception 'FAIL: second generation created % rows (expected 0)',
      current_setting('test.created2');
  end if;

  begin
    insert into public.recurring_rules
      (household_id, category_id, member_id, amount, frequency, next_due, name)
    values (current_setting('test.hh_a')::uuid, current_setting('test.category_a')::uuid,
            current_setting('test.member_a')::uuid, 50.00, 'weekly', current_date - 5, '   ');
    raise exception 'FAIL: blank recurring-rule name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  -- A future-dated rule generates nothing.
  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, next_due, name)
  values (current_setting('test.hh_a')::uuid, current_setting('test.category_a')::uuid,
          current_setting('test.member_a')::uuid, 30.00, 'weekly', current_date + 5, 'Later');
end $$;

select set_config('test.created3', public.generate_recurring_transactions()::text, false);

do $$
begin
  if current_setting('test.created3') <> '0' then
    raise exception 'FAIL: future rule generated % rows (expected 0)',
      current_setting('test.created3');
  end if;
end $$;

-- 8.5 Child C is fully locked out of the whole feature set.
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

do $$
declare n int;
begin
  select count(*) into n from public.vehicles;
  if n <> 0 then raise exception 'FAIL: child sees % vehicles (expected 0)', n; end if;
  select count(*) into n from public.fuel_logs;
  if n <> 0 then raise exception 'FAIL: child sees % fuel logs (expected 0)', n; end if;
  select count(*) into n from public.maintenance_items;
  if n <> 0 then raise exception 'FAIL: child sees % maintenance items (expected 0)', n; end if;
  select count(*) into n from public.recurring_rules;
  if n <> 0 then raise exception 'FAIL: child sees % recurring rules (expected 0)', n; end if;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      current_date, 11000, 40, 9000, false);
    raise exception 'FAIL: child added a fuel log';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.delete_fuel_log(current_setting('test.fuel1')::uuid);
    raise exception 'FAIL: child deleted a fuel log';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.complete_maintenance(current_setting('test.item1')::uuid, 100);
    raise exception 'FAIL: child completed maintenance';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    insert into public.fuel_logs (household_id, vehicle_id, odometer_km, total_cost)
    values (current_setting('test.hh_a')::uuid,
            current_setting('test.vehicle_a')::uuid, 11000, 50);
    raise exception 'FAIL: child inserted a fuel log directly';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.maintenance_items (household_id, vehicle_id, name, due_date)
    values (current_setting('test.hh_a')::uuid,
            current_setting('test.vehicle_a')::uuid, 'Kid Item', current_date);
    raise exception 'FAIL: child inserted a maintenance item';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.recurring_rules
      (household_id, category_id, member_id, amount, frequency, next_due)
    values (current_setting('test.hh_a')::uuid,
            current_setting('test.category_a')::uuid,
            current_setting('test.member_a')::uuid, 10, 'weekly', current_date);
    raise exception 'FAIL: child inserted a recurring rule';
  exception when insufficient_privilege then null;
  end;

  update public.maintenance_items set due_date = current_date + 1;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child updated % maintenance items', n; end if;
  delete from public.maintenance_items;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child deleted % maintenance items', n; end if;
end $$;

-- 8.6 Outsider H (no household) is locked out too.
set local request.jwt.claims to '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated"}';
set local request.jwt.claim.sub to '88888888-8888-4888-8888-888888888888';

do $$
declare n int;
begin
  select count(*) into n from public.vehicles;
  if n <> 0 then raise exception 'FAIL: outsider sees % vehicles (expected 0)', n; end if;
  select count(*) into n from public.fuel_logs;
  if n <> 0 then raise exception 'FAIL: outsider sees % fuel logs (expected 0)', n; end if;
  select count(*) into n from public.maintenance_items;
  if n <> 0 then raise exception 'FAIL: outsider sees % maintenance items (expected 0)', n; end if;

  begin
    perform public.add_fuel_log(current_setting('test.vehicle_a')::uuid,
      current_date, 11000, 40, 9000, false);
    raise exception 'FAIL: outsider added a fuel log';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.delete_fuel_log(current_setting('test.fuel1')::uuid);
    raise exception 'FAIL: outsider deleted a fuel log';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;
end $$;

-- 8.7 Owner deletes a fuel log: the linked expense goes with it.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare n int;
begin
  begin
    perform public.delete_fuel_log('00000000-0000-0000-0000-000000000000');
    raise exception 'FAIL: deleting an unknown fuel log succeeded';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_log' then raise; end if;
  end;

  perform public.delete_fuel_log(current_setting('test.fuel1')::uuid);

  select count(*) into n from public.fuel_logs;
  if n <> 2 then raise exception 'FAIL: delete left % fuel logs (expected 2)', n; end if;
  select count(*) into n from public.transactions
   where id = current_setting('test.txn_fuel1')::uuid;
  if n <> 0 then raise exception 'FAIL: linked fuel expense survived the delete (%)', n; end if;
end $$;

-- 8.8 Owner still sees the whole Phase 3 picture.
do $$
declare n int;
begin
  select count(*) into n from public.vehicles;
  if n <> 2 then raise exception 'FAIL: owner sees % vehicles (expected 2)', n; end if;
  select count(*) into n from public.fuel_logs;
  if n <> 2 then raise exception 'FAIL: owner sees % fuel logs (expected 2)', n; end if;
  select count(*) into n from public.maintenance_items;
  if n <> 2 then raise exception 'FAIL: owner sees % maintenance items (expected 2)', n; end if;
  select count(*) into n from public.recurring_rules;
  if n <> 4 then raise exception 'FAIL: owner sees % recurring rules (expected 4)', n; end if;
  select count(*) into n from public.transactions where recurring_rule_id is not null;
  if n <> 9 then raise exception 'FAIL: owner sees % generated transactions (expected 9)', n; end if;
end $$;

-- --------------------------------------------------------------------
-- 7. Nothing above is persisted.
-- --------------------------------------------------------------------
select 'ALL RLS ISOLATION TESTS PASSED' as result;
do $$ begin raise notice 'ALL RLS ISOLATION TESTS PASSED'; end $$;

rollback;
