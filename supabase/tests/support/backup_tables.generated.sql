-- GENERATED FILE - DO NOT EDIT. Source of truth:
-- lib/features/backup/domain/backup_tables.dart, rendered by
-- tool/gen_backup_tables_sql.dart. tool/docker/validate.sh prepends
-- this to supabase/tests/support/check_backup_tables.sql.
drop table if exists backup_table_registry;
create temp table backup_table_registry (
  table_name text primary key,
  disposition text not null check (disposition in ('exported', 'excluded')),
  reason text
);
insert into backup_table_registry (table_name, disposition, reason) values
  ('households', 'exported', null),
  ('members', 'exported', null),
  ('household_users', 'exported', null),
  ('categories', 'exported', null),
  ('vehicles', 'exported', null),
  ('pets', 'exported', null),
  ('recurring_rules', 'exported', null),
  ('transactions', 'exported', null),
  ('transaction_receipts', 'exported', null),
  ('fuel_logs', 'exported', null),
  ('maintenance_items', 'exported', null),
  ('pet_reminders', 'exported', null),
  ('budgets', 'exported', null),
  ('invites', 'excluded', 'Invite codes are bearer credentials (access tokens), not household data. Exporting one would hand out access to the household.');
drop table if exists backup_text_columns;
create temp table backup_text_columns (
  table_name text not null,
  column_name text not null,
  primary key (table_name, column_name)
);
insert into backup_text_columns (table_name, column_name) values
  ('vehicles', 'current_odometer'),
  ('recurring_rules', 'amount'),
  ('transactions', 'amount'),
  ('transactions', 'odometer'),
  ('transactions', 'liters'),
  ('fuel_logs', 'odometer_km'),
  ('fuel_logs', 'liters'),
  ('fuel_logs', 'total_cost'),
  ('maintenance_items', 'due_odometer_km'),
  ('maintenance_items', 'interval_km'),
  ('budgets', 'amount');
