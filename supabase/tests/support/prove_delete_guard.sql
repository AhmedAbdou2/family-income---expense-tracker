-- Proof that the honest storage stub cannot mask a skipped delete.
--   (A) WITHOUT storage.allow_delete_query -> the guard must raise 42501 and
--       the row must survive (savepoint rolled back).
--   (B) WITH    storage.allow_delete_query -> the row must REALLY disappear.
-- Canonical copy: supabase/tests/support/prove_delete_guard.sql
-- Run against any DB built with stub_supabase.sql:
--   docker exec -i rls-pg psql -U postgres -d fresh17 \
--     -f - < supabase/tests/support/prove_delete_guard.sql
\set ON_ERROR_STOP off
begin;
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false) on conflict (id) do nothing;
insert into storage.objects (bucket_id, name, owner, metadata)
values ('receipts', 'hh/tx/a.jpg', null, '{}'::jsonb);

select 'A: before' as step, count(*) as rows
  from storage.objects where name = 'hh/tx/a.jpg';

-- (A) no GUC: expect ERROR 42501 and the row still present after rollback.
savepoint a;
delete from storage.objects where name = 'hh/tx/a.jpg';
rollback to savepoint a;
select 'A: after failed delete' as step, count(*) as rows
  from storage.objects where name = 'hh/tx/a.jpg';

-- (B) mimic the Storage API: set the GUC, then the row really goes away.
set local storage.allow_delete_query = 'true';
delete from storage.objects where name = 'hh/tx/a.jpg';
select 'B: after allowed delete' as step, count(*) as rows
  from storage.objects where name = 'hh/tx/a.jpg';
rollback;
