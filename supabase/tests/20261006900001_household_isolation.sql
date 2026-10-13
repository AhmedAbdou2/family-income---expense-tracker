-- ===================================================================
-- RLS ISOLATION TEST - Phase 1 + 2 + 2.5 + 3 + 3.5 + 4a + 4b extensions
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
-- Phase 3.5 additions (section 9):
--   * the new 'pet' category group: a household gets 37 default
--     categories (31 + 6 pet);
--   * pets are owner/adult-only: a child and an outsider see ZERO pet
--     rows and cannot insert/update/delete them; pet names are trimmed
--     + length-checked (1..40);
--   * transactions.pet_id integrity: an expense may reference a pet of
--     the SAME household only (foreign pet id -> denied);
--   * recurring rules carry vehicle_id + pet_id onto the transactions
--     they post.
--
-- Phase 3.6 additions (section 10):
--   * archiving a fixed commitment keeps the posted transaction's
--     recurring_rule_id (the link survives), leaves the rule inactive +
--     archived, and the generator ignores it from then on;
--   * delete-this-month purges only that rule's current-month rows in the
--     same atomic call that archives;
--   * double archive -> already_archived, unknown -> invalid_rule;
--   * direct DELETE on recurring_rules is revoked; a child and an
--     outsider get forbidden.
--
-- Phase 4a additions (section 11):
--   * budgets are one-per-category + one overall, paused rows keep the
--     slot, writes are RPC-only, children/outsiders are locked out;
--   * monthly_totals stays exact past 1000 rows and matches the
--     dashboard definition.
--
-- Phase 4b additions (sections 12-13):
--   * receipts: the private bucket's real limits, a server-minted path,
--     stored mime/size winning over the client's, the 3-per-transaction
--     cap, child/outsider/anon lockout on the table AND the storage
--     object, and the AMENDMENT A proof that an adult can still delete a
--     transaction's objects after the row is gone (orphan sweep included);
--   * delete_transaction keeps the exact old delete rule (owner/adult any
--     row, child only its own person, foreign adult forbidden);
--   * pet reminders: validation, repeat-clamp (Jan 31 -> Feb 28), an
--     optional pet expense in the right pet category, the no-linked-person
--     rule (raises, writes nothing), and child/outsider lockout.
--
-- Logins used: A + B (isolation), C + D + E (phase 2), F + G + H
-- (phase 2.5 joiners/legacy), J + K + L (role / leave / remove cast),
-- M (phase 4b: an adult with no person of their own).
--
-- HOW TO RUN: paste this ENTIRE file into the Supabase SQL editor and run
-- it. It executes inside ONE transaction and always ROLLS BACK, so it
-- leaves no data behind. Success = green notice below; any failure =
-- red error starting with "FAIL:" or "TEST SETUP FAILED:".
--
-- Prerequisite: migrations 1..17 have been run in that order.
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

-- Migration 16: budgets are write-through-RPC only (direct INSERT is
-- revoked from authenticated).
select set_config('test.budget_a', public.set_category_budget(
  current_setting('test.hh_a')::uuid,
  current_setting('test.category_a')::uuid, 500.00)::text, false);

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

  -- 5.5 Migration 16: budgets are owner/adult-only. A child sees ZERO
  --     budget rows, and every budget RPC raises 'forbidden'.
  select count(*) into n from public.budgets;
  if n <> 0 then raise exception 'FAIL: child sees % budget rows (expected 0)', n; end if;

  begin
    perform public.set_budget_active(current_setting('test.budget_a')::uuid, false);
    raise exception 'FAIL: child paused a budget via RPC';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.delete_budget(current_setting('test.budget_a')::uuid);
    raise exception 'FAIL: child deleted a budget via RPC';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.set_category_budget(
      current_setting('test.hh_a')::uuid,
      current_setting('test.category_a')::uuid, 1.00);
    raise exception 'FAIL: child set a category budget via RPC';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.set_overall_budget(current_setting('test.hh_a')::uuid, 1.00);
    raise exception 'FAIL: child set the overall budget via RPC';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.monthly_totals(
      current_setting('test.hh_a')::uuid,
      date_trunc('month', current_date)::date,
      (date_trunc('month', current_date) + interval '1 month')::date);
    raise exception 'FAIL: child called monthly_totals';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
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
  if n <> 37 then raise exception 'FAIL: owner sees % categories (expected 37)', n; end if;
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
-- 9. PHASE 3.5: pets (owner/adult-only) + pet categories + pet/vehicle
--    links on fixed commitments.
-- --------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- 9.0 Owner A seeds a pet; the name trigger trims + validates.
do $$
declare v_pet uuid; n int;
begin
  begin
    insert into public.pets (household_id, name, type)
    values (current_setting('test.hh_a')::uuid, '   ', 'cat');
    raise exception 'FAIL: blank pet name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  begin
    insert into public.pets (household_id, name, type)
    values (current_setting('test.hh_a')::uuid, repeat('p', 41), 'cat');
    raise exception 'FAIL: 41-char pet name accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  insert into public.pets (household_id, name, type, birth_date)
  values (current_setting('test.hh_a')::uuid, '  Simba  ', 'cat', current_date - 365)
  returning id into v_pet;
  perform set_config('test.pet_a', v_pet::text, false);

  select count(*) into n from public.pets
   where id = v_pet and name = 'Simba';
  if n <> 1 then raise exception 'FAIL: pet name trigger did not trim (%)', n; end if;
end $$;

-- 9.1 The household has 37 default categories (31 + 6 pet).
do $$
declare n int;
begin
  select count(*) into n from public.categories
   where household_id = current_setting('test.hh_a')::uuid and "group" = 'pet';
  if n <> 6 then raise exception 'FAIL: owner sees % pet categories (expected 6)', n; end if;
  select count(*) into n from public.categories
   where household_id = current_setting('test.hh_a')::uuid;
  if n <> 37 then raise exception 'FAIL: owner sees % categories (expected 37)', n; end if;
end $$;

-- 9.2 Owner records a pet expense: allowed; it stores pet_id.
do $$
declare v_cat uuid; n int;
begin
  select c.id into v_cat from public.categories c
   where c.household_id = current_setting('test.hh_a')::uuid and c."group" = 'pet'
   order by c.name_en limit 1;

  insert into public.transactions (household_id, type, amount, category_id, member_id, pet_id, date)
  values (current_setting('test.hh_a')::uuid, 'expense', 15.00, v_cat,
          current_setting('test.member_a')::uuid,
          current_setting('test.pet_a')::uuid, current_date);

  select count(*) into n from public.transactions
   where pet_id = current_setting('test.pet_a')::uuid;
  if n <> 1 then raise exception 'FAIL: pet expense not stored (%)', n; end if;
end $$;

-- 9.3 Child C: zero pet access (SELECT + all writes).
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

do $$
declare n int;
begin
  select count(*) into n from public.pets;
  if n <> 0 then raise exception 'FAIL: child sees % pets (expected 0)', n; end if;

  begin
    insert into public.pets (household_id, name, type)
    values (current_setting('test.hh_a')::uuid, 'Kid Pet', 'dog');
    raise exception 'FAIL: child inserted a pet';
  exception when insufficient_privilege then null;
  end;

  update public.pets set name = 'pwned';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child updated % pets', n; end if;
  delete from public.pets;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child deleted % pets', n; end if;
end $$;

-- Outsider H sees zero pets too.
set local request.jwt.claims to '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated"}';
set local request.jwt.claim.sub to '88888888-8888-4888-8888-888888888888';

do $$
declare n int;
begin
  select count(*) into n from public.pets;
  if n <> 0 then raise exception 'FAIL: outsider sees % pets (expected 0)', n; end if;
end $$;

-- 9.4 Transaction integrity: a pet of ANOTHER household is rejected.
set local role none;
insert into public.pets (household_id, name, type)
values (current_setting('test.hh_j')::uuid, 'Foreign Pet', 'dog');
select set_config('test.pet_j', (
  select p.id from public.pets p
   where p.household_id = current_setting('test.hh_j')::uuid limit 1)::text, false);

set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare v_cat uuid;
begin
  select c.id into v_cat from public.categories c
   where c.household_id = current_setting('test.hh_a')::uuid and c."group" = 'pet'
   order by c.name_en limit 1;

  begin
    insert into public.transactions (household_id, type, amount, category_id, member_id, pet_id, date)
    values (current_setting('test.hh_a')::uuid, 'expense', 9.00, v_cat,
            current_setting('test.member_a')::uuid,
            current_setting('test.pet_j')::uuid, current_date);
    raise exception 'FAIL: transaction accepted a foreign household''s pet';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 9.5 A fixed commitment can carry a vehicle + pet link, and the posted
--     transaction inherits both.
do $$
declare v_rule uuid; v_cat uuid; n int;
begin
  select c.id into v_cat from public.categories c
   where c.household_id = current_setting('test.hh_a')::uuid and c."group" = 'pet'
   order by c.name_en limit 1;

  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, next_due,
     name, vehicle_id, pet_id)
  values (current_setting('test.hh_a')::uuid, v_cat,
          current_setting('test.member_a')::uuid, 120.00, 'monthly',
          current_date - 1, 'Pet Insurance',
          current_setting('test.vehicle_a')::uuid,
          current_setting('test.pet_a')::uuid)
  returning id into v_rule;

  perform public.generate_recurring_transactions();

  select count(*) into n from public.transactions
   where recurring_rule_id = v_rule
     and vehicle_id = current_setting('test.vehicle_a')::uuid
     and pet_id = current_setting('test.pet_a')::uuid;
  if n <> 1 then raise exception 'FAIL: linked fixed commitment lost its links (%)', n; end if;
end $$;

-- 9.6 Owner still sees the pets + linked rows.
do $$
declare n int;
begin
  select count(*) into n from public.pets;
  if n <> 1 then raise exception 'FAIL: owner sees % pets (expected 1)', n; end if;
end $$;

-- --------------------------------------------------------------------
-- 10. PHASE 3.6: archiving a fixed commitment (migration 15)
--   * archive keeps the posted transaction's recurring_rule_id (the link
--     survives - that is the whole bug fix);
--   * the archived rule is inactive + hidden and the generator skips it;
--   * delete-this-month purges only the rule's current-month rows, in the
--     same atomic call that archives;
--   * double archive -> already_archived, unknown -> invalid_rule;
--   * direct DELETE is revoked; a child and an outsider get forbidden.
-- --------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- 10.0 Owner A creates a rule that posts this month, then archives it
--      with "Keep".
do $$
declare v_rule uuid; v_tx uuid; n int;
begin
  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, day_of_month,
     next_due, start_date, is_active, name)
  values (current_setting('test.hh_a')::uuid, current_setting('test.category_a')::uuid,
          current_setting('test.member_a')::uuid, 2000.00, 'monthly',
          extract(day from current_date)::int, current_date, current_date, true,
          'Archive Me')
  returning id into v_rule;

  perform public.generate_recurring_transactions();

  select count(*) into n from public.transactions where recurring_rule_id = v_rule;
  if n <> 1 then raise exception 'FAIL: archive rule posted % rows (expected 1)', n; end if;
  select id into v_tx from public.transactions where recurring_rule_id = v_rule;
  perform set_config('test.archive_rule', v_rule::text, false);
  perform set_config('test.archive_tx', v_tx::text, false);
end $$;

do $$
declare
  v_rule uuid := current_setting('test.archive_rule')::uuid;
  v_res jsonb;
  n int;
begin
  -- Migration 17: the RPC now returns jsonb {deleted, receipt_paths}.
  v_res := public.archive_recurring_rule(v_rule, false);
  if (v_res ->> 'deleted')::int <> 0 then
    raise exception 'FAIL: keep-archive reported a deleted row';
  end if;
  if v_res ->> 'receipt_paths' <> '[]' then
    raise exception 'FAIL: keep-archive handed back receipt paths';
  end if;

  select count(*) into n from public.recurring_rules
   where id = v_rule and archived_at is not null and is_active = false;
  if n <> 1 then raise exception 'FAIL: rule not archived + inactive'; end if;

  -- The bug: the posted row must KEEP its link.
  select count(*) into n from public.transactions
   where id = current_setting('test.archive_tx')::uuid and recurring_rule_id = v_rule;
  if n <> 1 then raise exception 'FAIL: keep-archive broke the posted link'; end if;

  -- Re-running the generator adds nothing for the archived rule.
  perform public.generate_recurring_transactions();
  select count(*) into n from public.transactions where recurring_rule_id = v_rule;
  if n <> 1 then raise exception 'FAIL: archived rule generated new rows (%)', n; end if;

  -- Archived rows stay SELECTable by the household (the app hides them).
  select count(*) into n from public.recurring_rules where id = v_rule;
  if n <> 1 then raise exception 'FAIL: owner cannot select the archived rule'; end if;
end $$;

-- 10.1 delete-this-month purges only the rule''s current-month rows and
--      archives, all in one call.
do $$
declare v_rule uuid; n int;
begin
  insert into public.recurring_rules
    (household_id, category_id, member_id, amount, frequency, day_of_month,
     next_due, start_date, is_active, name)
  values (current_setting('test.hh_a')::uuid, current_setting('test.category_a')::uuid,
          current_setting('test.member_a')::uuid, 300.00, 'monthly',
          extract(day from current_date)::int, current_date, current_date, true,
          'Purge Me')
  returning id into v_rule;

  perform public.generate_recurring_transactions();
  select count(*) into n from public.transactions where recurring_rule_id = v_rule;
  if n <> 1 then raise exception 'FAIL: purge rule posted % rows (expected 1)', n; end if;

  if (public.archive_recurring_rule(v_rule, true) ->> 'deleted')::int <> 1 then
    raise exception 'FAIL: delete-month did not report 1 deleted row';
  end if;

  select count(*) into n from public.transactions where recurring_rule_id = v_rule;
  if n <> 0 then raise exception 'FAIL: delete-month left % linked rows', n; end if;
  select count(*) into n from public.recurring_rules
   where id = v_rule and archived_at is not null and is_active = false;
  if n <> 1 then raise exception 'FAIL: purge rule not archived'; end if;
end $$;

-- 10.2 Error cases: double archive + unknown rule.
do $$
begin
  begin
    perform public.archive_recurring_rule(current_setting('test.archive_rule')::uuid, false);
    raise exception 'FAIL: double archive was allowed';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'already_archived' then raise; end if;
  end;

  begin
    perform public.archive_recurring_rule('00000000-0000-0000-0000-000000000000', false);
    raise exception 'FAIL: archiving an unknown rule succeeded';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_rule' then raise; end if;
  end;
end $$;

-- 10.3 Direct DELETE on recurring_rules is gone for the owner.
do $$
declare n int;
begin
  delete from public.recurring_rules where id = current_setting('test.archive_rule')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: owner deleted % rules directly', n; end if;
exception when insufficient_privilege then null;
end $$;

-- 10.4 Child B cannot archive A''s rule.
set local request.jwt.claims to '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}';
set local request.jwt.claim.sub to '22222222-2222-4222-8222-222222222222';

do $$
begin
  perform public.archive_recurring_rule(current_setting('test.archive_rule')::uuid, false);
  raise exception 'FAIL: child archived a rule';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  if sqlerrm <> 'forbidden' then raise; end if;
end $$;

-- 10.5 Outsider H cannot archive A''s rule.
set local request.jwt.claims to '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated"}';
set local request.jwt.claim.sub to '88888888-8888-4888-8888-888888888888';

do $$
begin
  perform public.archive_recurring_rule(current_setting('test.archive_rule')::uuid, false);
  raise exception 'FAIL: outsider archived a rule';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  if sqlerrm <> 'forbidden' then raise; end if;
end $$;

-- --------------------------------------------------------------------
-- 11. PHASE 4: budgets (migration 16) + monthly_totals aggregation
-- --------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- 11.0 One limit per category: setting the same category again UPDATES
--      the same row (budget_a was created in 5.0 with 500.00).
select set_config('test.budget_a2', public.set_category_budget(
  current_setting('test.hh_a')::uuid,
  current_setting('test.category_a')::uuid, 750.00)::text, false);

do $$
declare n int; v_amt numeric;
begin
  if current_setting('test.budget_a2') is distinct from current_setting('test.budget_a') then
    raise exception 'FAIL: re-setting a category budget created a second row';
  end if;
  select count(*) into n from public.budgets
   where household_id = current_setting('test.hh_a')::uuid
     and category_id = current_setting('test.category_a')::uuid;
  if n <> 1 then raise exception 'FAIL: % budget rows for one category (expected 1)', n; end if;
  select amount into v_amt from public.budgets where id = current_setting('test.budget_a')::uuid;
  if v_amt <> 750.00 then raise exception 'FAIL: category budget amount not updated (%)', v_amt; end if;
end $$;

-- 11.1 Overall limit: exactly one row, category_id null.
select set_config('test.budget_overall', public.set_overall_budget(
  current_setting('test.hh_a')::uuid, 2000.00)::text, false);

do $$
declare n int;
begin
  select count(*) into n from public.budgets
   where household_id = current_setting('test.hh_a')::uuid and category_id is null;
  if n <> 1 then raise exception 'FAIL: overall budget rows = % (expected 1)', n; end if;
end $$;

-- 11.2 Pause keeps the row; resume flips it back; delete removes it.
do $$
declare n int;
begin
  perform public.set_budget_active(current_setting('test.budget_overall')::uuid, false);
  select count(*) into n from public.budgets
   where id = current_setting('test.budget_overall')::uuid and is_active = false;
  if n <> 1 then raise exception 'FAIL: pause did not keep the row inactive (%)', n; end if;

  perform public.set_budget_active(current_setting('test.budget_overall')::uuid, true);
  select count(*) into n from public.budgets
   where id = current_setting('test.budget_overall')::uuid and is_active = true;
  if n <> 1 then raise exception 'FAIL: resume failed (%)', n; end if;
end $$;

do $$
begin
  perform public.delete_budget(current_setting('test.budget_overall')::uuid);
  if (select count(*) from public.budgets where id = current_setting('test.budget_overall')::uuid) <> 0 then
    raise exception 'FAIL: delete_budget left the row behind';
  end if;
  begin
    perform public.delete_budget(current_setting('test.budget_overall')::uuid);
    raise exception 'FAIL: deleting an unknown budget succeeded';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_budget' then raise; end if;
  end;
end $$;

-- 11.3 Amount validation: zero, negative, too many decimals -> invalid_value.
do $$
begin
  begin
    perform public.set_overall_budget(current_setting('test.hh_a')::uuid, 0);
    raise exception 'FAIL: zero overall budget accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.set_overall_budget(current_setting('test.hh_a')::uuid, -5);
    raise exception 'FAIL: negative overall budget accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.set_category_budget(current_setting('test.hh_a')::uuid,
                                       current_setting('test.category_a')::uuid, 10.555);
    raise exception 'FAIL: 3-decimal amount accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.set_category_budget(current_setting('test.hh_a')::uuid,
                                       '00000000-0000-0000-0000-000000000000', 10.00);
    raise exception 'FAIL: unknown category accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_category' then raise; end if;
  end;
end $$;

-- 11.4 Cross-household category rejected: grab one of hh_j's categories
--      (as J), then try to attach it to hh_a (as A).
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';
select set_config('test.category_j', (
  select c.id from public.categories c
   where c.household_id = current_setting('test.hh_j')::uuid
   limit 1)::text, false);

set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
begin
  begin
    perform public.set_category_budget(current_setting('test.hh_a')::uuid,
                                       current_setting('test.category_j')::uuid, 100.00);
    raise exception 'FAIL: set a budget for another household''s category';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_category' then raise; end if;
  end;
end $$;

-- 11.5 Deleting an unused category cascades its budget row away.
do $$
declare v_cat uuid; v_budget uuid;
begin
  insert into public.categories (household_id, "group", name_en, name_ar)
  values (current_setting('test.hh_a')::uuid, 'general', 'Budget Temp', 'Budget Temp')
  returning id into v_cat;

  v_budget := public.set_category_budget(current_setting('test.hh_a')::uuid, v_cat, 300.00);
  if (select count(*) from public.budgets where id = v_budget) <> 1 then
    raise exception 'FAIL: cascade setup budget missing';
  end if;

  delete from public.categories where id = v_cat;
  if (select count(*) from public.budgets where id = v_budget) <> 0 then
    raise exception 'FAIL: deleting the category left its budget behind';
  end if;
end $$;

-- 11.6 monthly_totals: aggregated in the DB, exact even past 1000 rows.
do $$
declare
  v_hh uuid := current_setting('test.hh_a')::uuid;
  v_mem uuid := current_setting('test.member_a')::uuid;
  v_cat uuid := current_setting('test.category_a')::uuid;
  v_old date := (date_trunc('month', current_date) - interval '24 months')::date;
  v_old_end date := (date_trunc('month', current_date) - interval '23 months')::date;
  v_curr date := date_trunc('month', current_date)::date;
  v_curr_end date := (date_trunc('month', current_date) + interval '1 month')::date;
  v_n int;
  v_months int;
  v_income bigint; v_expense bigint;
  v_rpc_income bigint; v_rpc_expense bigint;
begin
  -- 1001 expenses of 1.11 in an otherwise-empty month 24 months back.
  insert into public.transactions (household_id, type, amount, category_id, member_id, date)
  select v_hh, 'expense', 1.11, v_cat, v_mem, v_old + (g % 28)::int
    from generate_series(1, 1001) g;

  select count(*) into v_n from public.transactions
   where household_id = v_hh and date >= v_old and date < v_old_end;
  if v_n <> 1001 then raise exception 'FAIL: seeded % rows (expected 1001)', v_n; end if;

  select income_minor, expense_minor into v_rpc_income, v_rpc_expense
    from public.monthly_totals(v_hh, v_old, v_old_end)
   where month_start = v_old;

  if v_rpc_expense is distinct from 111111 then
    raise exception 'FAIL: >1000-row month expense = % (expected 111111)', v_rpc_expense;
  end if;
  if v_rpc_income is distinct from 0 then
    raise exception 'FAIL: >1000-row month income = % (expected 0)', v_rpc_income;
  end if;

  -- Same definitions as the dashboard: RPC == direct sum for the month.
  select (coalesce(sum(amount) filter (where type = 'income'), 0) * 100)::bigint,
         (coalesce(sum(amount) filter (where type = 'expense'), 0) * 100)::bigint
    into v_income, v_expense
    from public.transactions
   where household_id = v_hh and date >= v_curr and date < v_curr_end;

  select income_minor, expense_minor into v_rpc_income, v_rpc_expense
    from public.monthly_totals(v_hh, v_curr, v_curr_end)
   where month_start = v_curr;

  if v_rpc_income is distinct from v_income then
    raise exception 'FAIL: RPC income % <> direct %', v_rpc_income, v_income;
  end if;
  if v_rpc_expense is distinct from v_expense then
    raise exception 'FAIL: RPC expense % <> direct %', v_rpc_expense, v_expense;
  end if;

  -- Empty months are omitted: the row count equals the number of months
  -- that actually carry transactions (not every month in the window).
  select count(*) into v_n from public.monthly_totals(v_hh, v_old, v_curr_end);
  select count(distinct date_trunc('month', t.date)::date) into v_months
    from public.transactions t
   where t.household_id = v_hh and t.date >= v_old and t.date < v_curr_end;
  if v_n <> v_months then
    raise exception 'FAIL: monthly_totals returned % rows, distinct months = %', v_n, v_months;
  end if;

  -- Bad ranges are rejected.
  begin
    perform public.monthly_totals(v_hh, v_curr_end, v_curr);
    raise exception 'FAIL: inverted range accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  raise notice 'MONTHLY_TOTALS PASSED (1001 rows exact, dashboard-identical)';
end $$;

-- 11.7 Outsider H stays locked out of every budget RPC.
set local request.jwt.claims to '{"sub":"88888888-8888-4888-8888-888888888888","role":"authenticated"}';
set local request.jwt.claim.sub to '88888888-8888-4888-8888-888888888888';

do $$
begin
  begin
    perform public.set_category_budget(current_setting('test.hh_a')::uuid,
                                       current_setting('test.category_a')::uuid, 1.00);
    raise exception 'FAIL: outsider set a category budget';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.monthly_totals(current_setting('test.hh_a')::uuid,
                                  date_trunc('month', current_date)::date,
                                  (date_trunc('month', current_date) + interval '1 month')::date);
    raise exception 'FAIL: outsider called monthly_totals';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;
end $$;

-- --------------------------------------------------------------------
-- 12. PHASE 4b: transaction receipts + receipt-aware deletion (17)
-- --------------------------------------------------------------------
-- 12.0 The bucket exists, is PRIVATE, and carries the real server-side
--      size cap + mime allow list.
--
--      METADATA READ -- runs as the privileged login role, on purpose.
--      On hosted Supabase storage.buckets has RLS enabled and NO policy lets
--      `authenticated` (or `anon`) read it, so a select made while acting as
--      authenticated silently returns zero rows ("bucket missing" even though
--      the bucket is there -- the bug this section hit on the cloud). This
--      check is about migration 17's bucket CONFIGURATION, not about RLS, so
--      it runs as the privileged login role (`set local role none` = the
--      migration runner). Everything below runs as the real roles, and every
--      storage.objects read/write still goes through the real policies.
set local role none;
do $$
declare v_public boolean; v_limit bigint; v_mimes text[];
begin
  select b.public, b.file_size_limit, b.allowed_mime_types
    into v_public, v_limit, v_mimes
    from storage.buckets b where b.id = 'receipts';
  if not found then raise exception 'FAIL: receipts bucket missing'; end if;
  if v_public is not false then raise exception 'FAIL: receipts bucket is public'; end if;
  if v_limit <> 5242880 then raise exception 'FAIL: bucket size limit = %', v_limit; end if;
  if v_mimes is distinct from
     array['image/jpeg','image/png','image/webp','application/pdf']::text[] then
    raise exception 'FAIL: bucket mime list = %', v_mimes;
  end if;
end $$;

set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- 12.1 A fresh transaction to attach receipts to.
do $$
declare v_tx uuid;
begin
  insert into public.transactions (household_id, type, amount, category_id, member_id, date)
  values (current_setting('test.hh_a')::uuid, 'expense', 40.00,
          current_setting('test.category_a')::uuid,
          current_setting('test.member_a')::uuid, current_date)
  returning id into v_tx;
  perform set_config('test.receipt_tx', v_tx::text, false);
end $$;

-- 12.2 request_receipt_upload mints the path from the transaction row.
do $$
declare v_path text;
begin
  v_path := public.request_receipt_upload(
    current_setting('test.receipt_tx')::uuid, 'image/jpeg', 2048);
  if split_part(v_path, '/', 1) <> current_setting('test.hh_a') then
    raise exception 'FAIL: path household folder is %', v_path;
  end if;
  if split_part(v_path, '/', 2) <> current_setting('test.receipt_tx') then
    raise exception 'FAIL: path transaction folder is %', v_path;
  end if;
  if v_path !~ '\.jpg$' then raise exception 'FAIL: path extension is %', v_path; end if;
  perform set_config('test.receipt_path1', v_path, false);
end $$;

-- 12.3 AMENDMENT C: the stored object wins over the client's mime/size.
do $$
declare v_id uuid; v_mime text; v_size int;
begin
  insert into storage.objects (bucket_id, name, owner, metadata)
  values ('receipts', current_setting('test.receipt_path1'), auth.uid(),
          jsonb_build_object('mimetype', 'image/jpeg', 'size', 2048));

  -- The client LIES (says PDF, 4.9 MB). The row must record the object.
  v_id := public.attach_receipt(current_setting('test.receipt_tx')::uuid,
                                current_setting('test.receipt_path1'),
                                'application/pdf', 4999999);

  select r.mime, r.size_bytes into v_mime, v_size
    from public.transaction_receipts r where r.id = v_id;
  if v_mime <> 'image/jpeg' then
    raise exception 'FAIL: client mime trusted (stored %)', v_mime;
  end if;
  if v_size <> 2048 then
    raise exception 'FAIL: client size trusted (stored %)', v_size;
  end if;
  perform set_config('test.receipt1', v_id::text, false);
end $$;

-- 12.4 Three is the cap; a fourth is rejected.
do $$
declare v_p text; v_id uuid; i int;
begin
  for i in 1..2 loop
    v_p := public.request_receipt_upload(
      current_setting('test.receipt_tx')::uuid, 'image/png', 1024);
    insert into storage.objects (bucket_id, name, owner, metadata)
    values ('receipts', v_p, auth.uid(),
            jsonb_build_object('mimetype', 'image/png', 'size', 1024));
    v_id := public.attach_receipt(current_setting('test.receipt_tx')::uuid,
                                  v_p, 'image/png', 1024);
    perform set_config('test.receipt_path' || (i + 1), v_p, false);
  end loop;

  if (select count(*) from public.transaction_receipts
       where transaction_id = current_setting('test.receipt_tx')::uuid) <> 3 then
    raise exception 'FAIL: expected exactly 3 receipts';
  end if;

  begin
    perform public.request_receipt_upload(
      current_setting('test.receipt_tx')::uuid, 'image/png', 1024);
    raise exception 'FAIL: a 4th receipt was allowed';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'limit_reached' then raise; end if;
  end;
end $$;

-- 12.5 Attachment validation.
do $$
begin
  begin
    perform public.attach_receipt(current_setting('test.receipt_tx')::uuid,
      current_setting('test.hh_a') || '/' || current_setting('test.receipt_tx') ||
      '/99999999-9999-4999-8999-999999999999.jpg', 'image/jpeg', 100);
    raise exception 'FAIL: attach accepted an object that does not exist';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_receipt' then raise; end if;
  end;

  begin
    perform public.attach_receipt(current_setting('test.receipt_tx')::uuid,
      '00000000-0000-4000-8000-000000000000/' || current_setting('test.receipt_tx') ||
      '/x.jpg', 'image/jpeg', 100);
    raise exception 'FAIL: attach accepted a foreign-household path';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_receipt' then raise; end if;
  end;

  begin
    perform public.request_receipt_upload(
      current_setting('test.receipt_tx')::uuid, 'image/gif', 100);
    raise exception 'FAIL: a gif was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_mime' then raise; end if;
  end;

  begin
    perform public.request_receipt_upload(
      current_setting('test.receipt_tx')::uuid, 'image/png', 5242881);
    raise exception 'FAIL: an oversize upload was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.request_receipt_upload(
      current_setting('test.receipt_tx')::uuid, 'image/png', 0);
    raise exception 'FAIL: a zero-size upload was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.request_receipt_upload('00000000-0000-4000-8000-000000000000',
                                           'image/png', 10);
    raise exception 'FAIL: an unknown transaction was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_transaction' then raise; end if;
  end;
end $$;

-- 12.6 Receipts are RPC-only: a direct insert is denied.
do $$
begin
  begin
    insert into public.transaction_receipts
      (household_id, transaction_id, storage_path, mime, size_bytes)
    values
      (current_setting('test.hh_a')::uuid, current_setting('test.receipt_tx')::uuid,
       'x/y/z.jpg', 'image/jpeg', 10);
    raise exception 'FAIL: a direct receipt insert was allowed';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 12.7 Child C: sees no receipts, cannot mint/attach/delete, and cannot
--      touch the storage object.
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

do $$
declare n int;
begin
  select count(*) into n from public.transaction_receipts;
  if n <> 0 then raise exception 'FAIL: child sees % receipt rows', n; end if;

  begin
    perform public.request_receipt_upload(current_setting('test.receipt_tx')::uuid,
                                           'image/png', 10);
    raise exception 'FAIL: child minted an upload path';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.attach_receipt(current_setting('test.receipt_tx')::uuid,
      current_setting('test.receipt_path1'), 'image/jpeg', 100);
    raise exception 'FAIL: child attached a receipt';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.delete_receipt(current_setting('test.receipt1')::uuid);
    raise exception 'FAIL: child deleted a receipt';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  select count(*) into n from storage.objects where bucket_id = 'receipts';
  if n <> 0 then raise exception 'FAIL: child sees % receipt objects', n; end if;

  begin
    insert into storage.objects (bucket_id, name, owner, metadata)
    values ('receipts', current_setting('test.receipt_path1'), auth.uid(), '{}'::jsonb);
    raise exception 'FAIL: child uploaded a receipt object';
  exception when insufficient_privilege then null;
  end;

  delete from storage.objects where name = current_setting('test.receipt_path1');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child deleted % receipt objects', n; end if;
end $$;

-- 12.8 Outsider J (adult of ANOTHER household): locked out the same way.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
declare n int;
begin
  select count(*) into n from public.transaction_receipts;
  if n <> 0 then raise exception 'FAIL: outsider sees % receipt rows', n; end if;
  select count(*) into n from storage.objects where bucket_id = 'receipts';
  if n <> 0 then raise exception 'FAIL: outsider sees % receipt objects', n; end if;
  select count(*) into n from public.list_orphan_receipts();
  if n <> 0 then raise exception 'FAIL: outsider sweep saw % objects', n; end if;

  begin
    perform public.request_receipt_upload(current_setting('test.receipt_tx')::uuid,
                                           'image/png', 10);
    raise exception 'FAIL: outsider minted an upload path';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner, metadata)
    values ('receipts', current_setting('test.receipt_path1'), auth.uid(), '{}'::jsonb);
    raise exception 'FAIL: outsider uploaded into another household folder';
  exception when insufficient_privilege then null;
  end;

  delete from storage.objects where name = current_setting('test.receipt_path1');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: outsider deleted % receipt objects', n; end if;
end $$;

-- 12.9 anon has no business with the bucket at all.
set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner, metadata)
    values ('receipts', current_setting('test.receipt_path1'), null, '{}'::jsonb);
    raise exception 'FAIL: anon uploaded a receipt object';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from storage.objects where name = current_setting('test.receipt_path1');
  exception when insufficient_privilege then null;
  end;
end $$;

set local role authenticated;

-- 12.10 AMENDMENT B: delete_transaction keeps the old delete rule.
--       Child C deletes only their own person's rows.
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

do $$
begin
  perform public.delete_transaction(current_setting('test.txn_kid')::uuid);
  if (select count(*) from public.transactions
       where id = current_setting('test.txn_kid')::uuid) <> 0 then
    raise exception 'FAIL: child could not delete their own transaction';
  end if;

  begin
    perform public.delete_transaction(current_setting('test.txn_a')::uuid);
    raise exception 'FAIL: child deleted another person''s transaction';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;
end $$;

-- 12.11 An adult of another household is forbidden too.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
begin
  begin
    perform public.delete_transaction(current_setting('test.txn_a')::uuid);
    raise exception 'FAIL: a foreign adult deleted a transaction';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;
end $$;

-- 12.12 An owner/adult may delete ANY row of their household.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare v_tx uuid; v_paths text[];
begin
  insert into public.transactions (household_id, type, amount, category_id, member_id, date)
  values (current_setting('test.hh_a')::uuid, 'expense', 3.00,
          current_setting('test.category_a')::uuid,
          current_setting('test.member_kid')::uuid, current_date)
  returning id into v_tx;

  v_paths := public.delete_transaction(v_tx);
  if cardinality(coalesce(v_paths, array[]::text[])) <> 0 then
    raise exception 'FAIL: unexpected receipt paths on a clean delete';
  end if;
  if (select count(*) from public.transactions where id = v_tx) <> 0 then
    raise exception 'FAIL: adult could not delete another person''s row';
  end if;

  begin
    perform public.delete_transaction('00000000-0000-4000-8000-000000000000');
    raise exception 'FAIL: an unknown transaction was deleted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_transaction' then raise; end if;
  end;
end $$;

-- 12.13 AMENDMENT A + the orphan sweep: once the transaction is gone its
--       receipts cascade away, the objects survive as orphans, the sweep
--       finds them, and the adult can STILL delete them.
do $$
declare v_paths text[]; n int;
begin
  v_paths := public.delete_transaction(current_setting('test.receipt_tx')::uuid);
  if cardinality(v_paths) <> 3 then
    raise exception 'FAIL: delete_transaction returned % paths (expected 3)', cardinality(v_paths);
  end if;
  if (select count(*) from public.transaction_receipts
       where transaction_id = current_setting('test.receipt_tx')::uuid) <> 0 then
    raise exception 'FAIL: receipt rows survived the transaction delete';
  end if;

  select count(*) into n from public.list_orphan_receipts() p where p = any(v_paths);
  if n <> 3 then raise exception 'FAIL: sweep found % orphans (expected 3)', n; end if;

  delete from storage.objects where name = any(v_paths);
  get diagnostics n = row_count;
  if n <> 3 then
    raise exception 'FAIL: could not delete the orphans after the row was gone (%)', n;
  end if;

  select count(*) into n from public.list_orphan_receipts();
  if n <> 0 then raise exception 'FAIL: % orphans survived the cleanup', n; end if;
end $$;

do $$ begin raise notice 'RECEIPTS PASSED (3 max, stored mime/size, orphan sweep, object delete after row gone)'; end $$;

-- --------------------------------------------------------------------
-- 13. PHASE 4b: pet reminders (migration 17)
-- --------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

-- 13.0 Create (title trimmed) a repeating reminder whose due date is the
--      31st, to prove the month clamp into a shorter month.
do $$
declare v_id uuid;
begin
  v_id := public.create_pet_reminder(current_setting('test.pet_a')::uuid,
                                     '  Rabies booster  ', 'vaccine',
                                     date '2026-01-31', 1);
  perform set_config('test.rem1', v_id::text, false);
  if (select title from public.pet_reminders where id = v_id) <> 'Rabies booster' then
    raise exception 'FAIL: reminder title was not trimmed';
  end if;
end $$;

-- 13.1 Validation.
do $$
begin
  begin
    perform public.create_pet_reminder(current_setting('test.pet_a')::uuid, 'X',
                                       'spa', current_date, null);
    raise exception 'FAIL: a bad kind was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.create_pet_reminder(current_setting('test.pet_a')::uuid, 'X',
                                       'vet', current_date, 0);
    raise exception 'FAIL: repeat 0 was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.create_pet_reminder(current_setting('test.pet_a')::uuid, 'X',
                                       'vet', current_date, 121);
    raise exception 'FAIL: repeat 121 was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_value' then raise; end if;
  end;

  begin
    perform public.create_pet_reminder(current_setting('test.pet_a')::uuid,
                                       repeat('x', 61), 'vet', current_date, null);
    raise exception 'FAIL: a 61-character title was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_name' then raise; end if;
  end;

  begin
    perform public.create_pet_reminder('00000000-0000-4000-8000-000000000000', 'X',
                                       'vet', current_date, null);
    raise exception 'FAIL: an unknown pet was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'invalid_pet' then raise; end if;
  end;

  -- A pet of another household is not "invalid" - the caller is simply
  -- not an adult of that household (same convention as add_fuel_log).
  begin
    perform public.create_pet_reminder(current_setting('test.pet_j')::uuid, 'X',
                                       'vet', current_date, null);
    raise exception 'FAIL: a foreign household''s pet was accepted';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;
end $$;

-- 13.2 Update works, and completing without an amount posts nothing.
do $$
declare v_id uuid; n int;
begin
  v_id := public.create_pet_reminder(current_setting('test.pet_a')::uuid,
                                     'Plain visit', 'vet', current_date, null);
  perform set_config('test.rem2', v_id::text, false);
  perform public.update_pet_reminder(v_id, 'Plain vet visit', 'vet',
                                     current_date + 3, null);
  if (select title from public.pet_reminders where id = v_id) <> 'Plain vet visit' then
    raise exception 'FAIL: update did not change the title';
  end if;

  select count(*) into n from public.transactions
   where pet_id = current_setting('test.pet_a')::uuid;
  perform public.complete_pet_reminder(v_id);
  if (select done_at is null from public.pet_reminders where id = v_id) then
    raise exception 'FAIL: completing did not set done_at';
  end if;
  if (select count(*) from public.pet_reminders where id = v_id) <> 1 then
    raise exception 'FAIL: a non-repeating reminder multiplied';
  end if;
  if (select count(*) from public.transactions
       where pet_id = current_setting('test.pet_a')::uuid) <> n then
    raise exception 'FAIL: completing without an amount posted an expense';
  end if;
end $$;

-- 13.3 Completing a repeating reminder keeps the history and schedules the
--      next one, clamping the day (Jan 31 -> Feb 28).
do $$
declare n int;
begin
  perform public.complete_pet_reminder(current_setting('test.rem1')::uuid);

  select count(*) into n from public.pet_reminders
   where id = current_setting('test.rem1')::uuid and done_at is not null;
  if n <> 1 then raise exception 'FAIL: the completed reminder is not marked done'; end if;

  select count(*) into n from public.pet_reminders
   where pet_id = current_setting('test.pet_a')::uuid
     and title = 'Rabies booster'
     and done_at is null
     and due_date = date '2026-02-28';
  if n <> 1 then raise exception 'FAIL: the next occurrence is not 2026-02-28 (got %)',
    (select due_date from public.pet_reminders
      where pet_id = current_setting('test.pet_a')::uuid and done_at is null
        and title = 'Rabies booster' limit 1); end if;
end $$;

-- 13.4 Completing with an amount posts ONE pet expense in a pet category
--      (Vaccines for a vaccine), for the caller's own person.
do $$
declare v_amt numeric; v_cat text; v_pet uuid; v_mem uuid; v_id uuid;
begin
  v_id := public.create_pet_reminder(current_setting('test.pet_a')::uuid,
                                     'Booster shot', 'vaccine', current_date, null);
  perform public.complete_pet_reminder(v_id, 12345, 'Annual booster');

  select t.amount, c.name_en, t.pet_id, t.member_id
    into v_amt, v_cat, v_pet, v_mem
    from public.transactions t
    join public.categories c on c.id = t.category_id
   where t.pet_id = current_setting('test.pet_a')::uuid
     and t.note = 'Annual booster';

  if v_amt <> 123.45 then raise exception 'FAIL: pet expense amount % (expected 123.45)', v_amt; end if;
  if v_cat <> 'Vaccines' then raise exception 'FAIL: pet expense category % (expected Vaccines)', v_cat; end if;
  if v_pet is distinct from current_setting('test.pet_a')::uuid then
    raise exception 'FAIL: pet expense is linked to the wrong pet';
  end if;
  if v_mem is distinct from current_setting('test.member_a')::uuid then
    raise exception 'FAIL: pet expense is linked to the wrong person';
  end if;
end $$;

-- 13.5 AMENDMENT G: an adult with no person of their own. Completing
--      WITHOUT an amount is fine; WITH an amount raises no_linked_person
--      and writes nothing at all (not even done_at).
set local role none;
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'authenticated', 'authenticated', 'rls-test-m@test.local', 'not-a-real-hash',
        now(), '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;

insert into public.household_users (household_id, user_id, role)
values (current_setting('test.hh_a')::uuid, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'adult')
on conflict (household_id, user_id) do nothing;

set local role authenticated;
set local request.jwt.claims to '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}';
set local request.jwt.claim.sub to 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

do $$
declare v_id uuid; n int; v_before int;
begin
  if public.is_household_adult(current_setting('test.hh_a')::uuid) is not true then
    raise exception 'TEST SETUP FAILED: the no-person login is not an adult';
  end if;
  select count(*) into n from public.members where user_id = auth.uid();
  if n <> 0 then raise exception 'TEST SETUP FAILED: the no-person login has a person'; end if;

  v_id := public.create_pet_reminder(current_setting('test.pet_a')::uuid,
                                     'No person', 'vet', current_date, null);
  perform set_config('test.rem_noperson', v_id::text, false);

  select count(*) into v_before from public.transactions
   where pet_id = current_setting('test.pet_a')::uuid;

  begin
    perform public.complete_pet_reminder(v_id, 5000, 'should not post');
    raise exception 'FAIL: an adult with no person posted a pet expense';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'no_linked_person' then raise; end if;
  end;

  -- The failed call must not have left any trace behind.
  if (select done_at is not null from public.pet_reminders where id = v_id) then
    raise exception 'FAIL: the failed completion left done_at set';
  end if;
  if (select count(*) from public.transactions
       where pet_id = current_setting('test.pet_a')::uuid) <> v_before then
    raise exception 'FAIL: the failed completion posted an expense';
  end if;

  -- Without an amount it works: no person is needed to tick a reminder off.
  perform public.complete_pet_reminder(v_id);
  if (select done_at is null from public.pet_reminders where id = v_id) then
    raise exception 'FAIL: a no-person completion without an amount failed';
  end if;
end $$;

-- 13.6 Child C: zero rows, every reminder RPC forbidden, no direct writes.
set local request.jwt.claims to '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}';
set local request.jwt.claim.sub to '33333333-3333-4333-8333-333333333333';

do $$
declare n int;
begin
  select count(*) into n from public.pet_reminders;
  if n <> 0 then raise exception 'FAIL: child sees % reminders', n; end if;

  begin
    perform public.create_pet_reminder(current_setting('test.pet_a')::uuid, 'X',
                                       'vet', current_date, null);
    raise exception 'FAIL: child created a reminder';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.update_pet_reminder(current_setting('test.rem2')::uuid, 'x',
                                       'vet', current_date, null);
    raise exception 'FAIL: child updated a reminder';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.complete_pet_reminder(current_setting('test.rem2')::uuid);
    raise exception 'FAIL: child completed a reminder';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.delete_pet_reminder(current_setting('test.rem2')::uuid);
    raise exception 'FAIL: child deleted a reminder';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    delete from public.pet_reminders;
    raise exception 'FAIL: child deleted reminder rows directly';
  exception when insufficient_privilege then null;
  end;
end $$;

-- 13.7 Outsider J: zero rows, every reminder RPC forbidden, no direct writes.
set local request.jwt.claims to '{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}';
set local request.jwt.claim.sub to '99999999-9999-4999-8999-999999999999';

do $$
declare n int;
begin
  select count(*) into n from public.pet_reminders;
  if n <> 0 then raise exception 'FAIL: outsider sees % reminders', n; end if;

  begin
    perform public.create_pet_reminder(current_setting('test.pet_a')::uuid, 'X',
                                       'vet', current_date, null);
    raise exception 'FAIL: outsider created a reminder for another household''s pet';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.delete_pet_reminder(current_setting('test.rem2')::uuid);
    raise exception 'FAIL: outsider deleted A''s reminder';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    perform public.complete_pet_reminder(current_setting('test.rem2')::uuid, 100);
    raise exception 'FAIL: outsider completed A''s reminder';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
    if sqlerrm <> 'forbidden' then raise; end if;
  end;

  begin
    insert into public.pet_reminders (household_id, pet_id, title, kind, due_date)
    values (current_setting('test.hh_j')::uuid, current_setting('test.pet_j')::uuid,
            'J reminder', 'vet', current_date);
    raise exception 'FAIL: outsider wrote a reminder row directly';
  exception when insufficient_privilege then null;
  end;
end $$;

do $$ begin raise notice 'PET REMINDERS PASSED (repeat clamp, pet expense, no-person rule, child/outsider lockout)'; end $$;

-- --------------------------------------------------------------------
-- 7. Nothing above is persisted.
-- --------------------------------------------------------------------
select 'ALL RLS ISOLATION TESTS PASSED' as result;
do $$ begin raise notice 'ALL RLS ISOLATION TESTS PASSED'; end $$;

rollback;
