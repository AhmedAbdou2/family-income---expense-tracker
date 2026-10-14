-- Backup completeness check (the "real" one).
--
-- Run by tool/docker/validate.sh, which prepends the generated registry:
--
--   cat supabase/tests/support/backup_tables.generated.sql \
--       supabase/tests/support/check_backup_tables.sql | psql ... -f -
--
-- It queries information_schema on a real Docker schema and refuses the build
-- unless EVERY public base table is registered in the exporter's table list or
-- in the explicit exclusion list (with a reason). A future table that nobody
-- classified - `goals` in Phase 5b, say - fails here until it is handled.
--
-- It also fails on a registry row that names a table which does not exist, so
-- a rename cannot leave a stale entry behind.

create temp table backup_public_tables as
select
  t.table_name,
  exists (
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = t.table_name
      and c.column_name = 'household_id'
  ) as has_household_id
from information_schema.tables t
where t.table_schema = 'public'
  and t.table_type = 'BASE TABLE';

do $$
declare
  v_unregistered text;
  v_stale text;
  v_reasonless text;
  v_float text;
begin
  -- 1. Every public table must be exported or explicitly excluded.
  select string_agg(
           pt.table_name || ' (household_id=' || pt.has_household_id || ')',
           ', ' order by pt.table_name)
    into v_unregistered
  from backup_public_tables pt
  left join backup_table_registry r on r.table_name = pt.table_name
  where r.table_name is null;

  if v_unregistered is not null then
    raise exception
      'BACKUP COMPLETENESS FAILED: public tables with no backup disposition: %',
      v_unregistered;
  end if;

  -- 2. No stale registry entries (a renamed/dropped table).
  select string_agg(r.table_name, ', ' order by r.table_name)
    into v_stale
  from backup_table_registry r
  where not exists (
    select 1 from backup_public_tables pt where pt.table_name = r.table_name
  );

  if v_stale is not null then
    raise exception
      'BACKUP COMPLETENESS FAILED: registered tables that do not exist: %',
      v_stale;
  end if;

  -- 3. Every exclusion carries a reason.
  select string_agg(r.table_name, ', ' order by r.table_name)
    into v_reasonless
  from backup_table_registry r
  where r.disposition = 'excluded'
    and coalesce(btrim(r.reason), '') = '';

  if v_reasonless is not null then
    raise exception
      'BACKUP COMPLETENESS FAILED: excluded tables without a reason: %',
      v_reasonless;
  end if;

  -- 4. Every `numeric` column of an exported table must be read as ::text
  --    (money -> minor units, quantities -> decimal strings). A new numeric
  --    column would otherwise come back as a float and break AGENTS.md rule 2.
  select string_agg(
           c.table_name || '.' || c.column_name,
           ', ' order by c.table_name, c.column_name)
    into v_float
  from information_schema.columns c
  join backup_table_registry r on r.table_name = c.table_name
  where c.table_schema = 'public'
    and c.data_type = 'numeric'
    and r.disposition = 'exported'
    and not exists (
      select 1 from backup_text_columns t
      where t.table_name = c.table_name and t.column_name = c.column_name
    );

  if v_float is not null then
    raise exception
      'BACKUP COMPLETENESS FAILED: exported tables with float-read numeric columns: %',
      v_float;
  end if;
end $$;

\echo 'BACKUP COMPLETENESS OK (every public table is exported or explicitly excluded, and every numeric column is read as text)'
