-- ===================================================================
-- RLS ISOLATION TEST - Phase 1 + Phase 2 extensions
-- ===================================================================
-- Proves that a user from household B cannot SELECT / INSERT / UPDATE /
-- DELETE any row of household A, and that child-role restrictions hold.
--
-- Phase 2 additions (section 5):
--   * a person-bound invite auto-links members.user_id on accept;
--   * a linked child can SELECT/INSERT transactions ONLY for their own
--     linked member;
--   * a child cannot EDIT categories, members or budgets (0 rows touched);
--   * member-bound invite edge cases (member_linked at create + accept).
--
-- HOW TO RUN: paste this ENTIRE file into the Supabase SQL editor and run
-- it. It executes inside ONE transaction and always ROLLS BACK, so it
-- leaves no data behind. Success = green notice below; any failure =
-- red error starting with "FAIL:" or "TEST SETUP FAILED:".
--
-- Prerequisite: migrations 1..11 have been run in that order.
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

select set_config('test.hh_a', public.create_household('Test HH A', 'SAR')::text, false);

insert into public.members (household_id, name)
values (current_setting('test.hh_a')::uuid, 'A Person');

select set_config('test.member_a', (
  select m.id from public.members m
  where m.household_id = current_setting('test.hh_a')::uuid
  limit 1)::text, false);

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

  update public.members
     set name = 'pwned'
   where household_id = current_setting('test.hh_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: B updated % rows of A''s members', n; end if;

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

select set_config('test.joined', public.accept_invite(current_setting('test.invite'))::text, false);

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

  -- 4b. ...but still CANNOT see A's person, or A's transaction
  --     (A Person is not linked to B's login).
  select count(*) into n from public.members;
  if n <> 0 then raise exception 'FAIL: child B sees % member rows (expected 0)', n; end if;
  select count(*) into n from public.transactions;
  if n <> 0 then raise exception 'FAIL: child B sees % transactions (expected 0)', n; end if;

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

  -- 5.4 Child cannot EDIT members - not even their OWN row.
  update public.members
     set name = 'renamed by kid'
   where household_id = current_setting('test.hh_a')::uuid;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: child edited % member rows', n; end if;

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
--     unlinked person; the second acceptance must fail with member_linked
--     (and must NOT consume the code or create a membership).
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
    if sqlerrm <> 'member_linked' then raise; end if;
  end;
end $$;

-- 5.8 USER A (owner) still sees the whole household: the child
--     restrictions above must NOT have narrowed the owner's view.
set local request.jwt.claims to '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}';
set local request.jwt.claim.sub to '11111111-1111-4111-8111-111111111111';

do $$
declare n int;
begin
  select count(*) into n from public.members;
  if n <> 3 then raise exception 'FAIL: owner sees % members (expected 3)', n; end if;
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
-- 6. Nothing above is persisted.
-- --------------------------------------------------------------------
select 'ALL RLS ISOLATION TESTS PASSED' as result;
do $$ begin raise notice 'ALL RLS ISOLATION TESTS PASSED'; end $$;

rollback;
