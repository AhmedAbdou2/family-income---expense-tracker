-- Privilege matrix (migration 17): every SECURITY DEFINER function must be
-- executable by authenticated only (never public/anon), except
-- seed_default_categories which nobody outside definer functions may call.
-- Plus: transaction_receipts + pet_reminders have NO direct
-- INSERT/UPDATE/DELETE for authenticated/anon (RPC-only writes), and the
-- recreated delete_fuel_log / archive_recurring_rule / delete_transaction
-- kept the exact grants after DROP + CREATE (amendment B).
-- Canonical copy: supabase/tests/support/privcheck17.sql
-- Run: docker exec -i rls-pg psql -U postgres -v ON_ERROR_STOP=1 -d fresh17 \
--        -f - < supabase/tests/support/privcheck17.sql
-- The `--- violations ---` query must return 0 rows.
\set ON_ERROR_STOP on

\echo '--- definer functions: pub / anon / auth (expect f / f / t) ---'
select p.oid::regprocedure::text as signature,
       has_function_privilege('public', p.oid, 'execute')        as pub,
       has_function_privilege('anon', p.oid, 'execute')          as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as auth
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prosecdef
 order by signature;

\echo '--- violations (should be empty; trigger functions excluded) ---'
select p.oid::regprocedure::text as signature
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prosecdef
   and not exists (select 1 from pg_trigger t where t.tgfoid = p.oid)
   and (
     has_function_privilege('public', p.oid, 'execute')
     or has_function_privilege('anon', p.oid, 'execute')
     or (p.proname <> 'seed_default_categories'
         and not has_function_privilege('authenticated', p.oid, 'execute'))
     or (p.proname = 'seed_default_categories'
         and has_function_privilege('authenticated', p.oid, 'execute'))
   );

\echo '--- recreated RPCs (amendment B): pub / anon / auth must be f / f / t ---'
select p.oid::regprocedure::text as signature,
       has_function_privilege('public', p.oid, 'execute')        as pub,
       has_function_privilege('anon', p.oid, 'execute')          as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as auth
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('delete_transaction', 'delete_fuel_log', 'archive_recurring_rule')
 order by signature;

\echo '--- phase 4b RPC return shapes ---'
select p.oid::regprocedure::text as signature, pg_get_function_result(p.oid) as result
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('delete_transaction', 'delete_fuel_log', 'archive_recurring_rule',
                     'request_receipt_upload', 'attach_receipt', 'delete_receipt',
                     'list_orphan_receipts', 'create_pet_reminder', 'update_pet_reminder',
                     'complete_pet_reminder', 'delete_pet_reminder')
 order by 1;

\echo '--- transaction_receipts grants by role (authenticated: SELECT only) ---'
select grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema='public' and table_name='transaction_receipts'
 order by grantee, privilege_type;

\echo '--- pet_reminders grants by role (authenticated: SELECT only) ---'
select grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema='public' and table_name='pet_reminders'
 order by grantee, privilege_type;

\echo '--- phase 4b table policies (SELECT only, adult) ---'
select tablename, policyname, cmd from pg_policies
 where schemaname='public' and tablename in ('transaction_receipts','pet_reminders')
 order by tablename, cmd;

\echo '--- receipt bucket + storage policies ---'
select id, public as is_public, file_size_limit, allowed_mime_types
  from storage.buckets where id = 'receipts';
select policyname, cmd, roles::text as roles, qual
  from pg_policies where schemaname='storage' and tablename='objects' order by cmd;

\echo '--- budgets table grants by role (unchanged from 16) ---'
select grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema='public' and table_name='budgets'
 order by grantee, privilege_type;
