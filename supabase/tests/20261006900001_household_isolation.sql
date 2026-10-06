-- ===================================================================
-- RLS ISOLATION TEST - Phase 1
-- ===================================================================
-- Proves that a user from household B cannot SELECT / INSERT / UPDATE /
-- DELETE any row of household A, and that child-role restrictions hold.
--
-- HOW TO RUN: paste this ENTIRE file into the Supabase SQL editor and run
-- it. It executes inside ONE transaction and always ROLLS BACK, so it
-- leaves no data behind. Success = green notice below; any failure =
-- red error starting with "FAIL:" or "TEST SETUP FAILED:".
--
-- Prerequisite: migrations 1..10 have been run in that order.
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
-- 5. Nothing above is persisted.
-- --------------------------------------------------------------------
select 'ALL RLS ISOLATION TESTS PASSED' as result;
do $$ begin raise notice 'ALL RLS ISOLATION TESTS PASSED'; end $$;

rollback;
