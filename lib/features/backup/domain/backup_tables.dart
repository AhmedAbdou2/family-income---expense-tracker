/// The tables a household backup reads, and the ones it deliberately skips.
///
/// THIS FILE IS THE SINGLE SOURCE OF TRUTH. The Dart exporter reads it
/// directly, and `tool/gen_backup_tables_sql.dart` turns it into
/// `supabase/tests/support/backup_tables.generated.sql`, which the Docker
/// completeness check (`supabase/tests/support/check_backup_tables.sql`) reads
/// against the real `information_schema`. A test keeps the generated file in
/// sync, so the exporter and the check can never drift.
///
/// Adding a table to the schema without deciding what the backup does with it
/// makes the Docker check fail (see `tool/docker/validate.sh`).
library;

/// The archive format version (bumped only when the JSON shape changes).
const int backupFormatVersion = 1;

/// The migration set this build knows about. Must equal the number of files in
/// `supabase/migrations/`; a test pins that so a new migration forces this to
/// be revisited.
const int backupSchemaVersion = 17;

/// Receipt bytes above this are warned about before the export starts.
const int backupWarnReceiptBytes = 100 * 1024 * 1024; // 100 MiB

/// Receipt bytes above this are refused: the ZIP is built in memory on web,
/// so a larger archive could kill the tab. Data-only export stays available.
const int backupMaxReceiptBytes = 300 * 1024 * 1024; // 300 MiB

/// One table in the backup, with everything the exporter needs to page it.
class BackupTable {
  const BackupTable({
    required this.name,
    required this.select,
    this.filterColumn = 'household_id',
    this.orderColumns = const ['id'],
    this.moneyColumns = const <String>{},
  });

  /// The `public` table name.
  final String name;

  /// PostgREST select list. Every `numeric` column is cast to `text` so no
  /// float ever touches the data: money becomes integer minor units and
  /// quantities stay exact decimal strings (see AGENTS.md). A reserved column
  /// name such as `"group"` is quoted.
  final String select;

  /// `id` for the root `households` row, `household_id` for every other table.
  final String filterColumn;

  /// Deterministic ordering so a page boundary cannot drop or repeat a row.
  final List<String> orderColumns;

  /// Columns holding MONEY. Exported as a `<name>_minor_units` integer, never
  /// as a decimal string, so every consumer works in integer minor units.
  final Set<String> moneyColumns;
}

/// Every table the backup reads, in dependency order (parents before children
/// so the JSON is easy to read).
const List<BackupTable> backupTables = <BackupTable>[
  BackupTable(
    name: 'households',
    select: 'id, name, currency, created_by, created_at',
    filterColumn: 'id',
  ),
  BackupTable(
    name: 'members',
    select: 'id, household_id, name, avatar, is_active, user_id, created_at',
  ),
  BackupTable(
    name: 'household_users',
    select: 'household_id, user_id, role, created_at',
    orderColumns: ['user_id'],
  ),
  BackupTable(
    name: 'categories',
    select:
        'id, household_id, "group", name_ar, name_en, icon, color, is_default, created_at',
  ),
  BackupTable(
    name: 'vehicles',
    select:
        'id, household_id, name, plate, current_odometer::text, created_at, fuel_type, is_active',
  ),
  BackupTable(
    name: 'pets',
    select: 'id, household_id, name, type, birth_date, notes, is_active, created_at',
  ),
  BackupTable(
    name: 'recurring_rules',
    select:
        'id, household_id, category_id, member_id, amount::text, frequency, day_of_month, '
        'next_due, is_active, created_by, created_at, name, start_date, end_date, '
        'vehicle_id, pet_id, archived_at',
    moneyColumns: {'amount'},
  ),
  BackupTable(
    name: 'transactions',
    select:
        'id, household_id, type, amount::text, category_id, member_id, vehicle_id, date, '
        'note, attachment_url, odometer::text, liters::text, recurring_rule_id, created_by, '
        'created_at, recurrence_date, pet_id',
    orderColumns: ['date', 'id'],
    moneyColumns: {'amount'},
  ),
  BackupTable(
    name: 'transaction_receipts',
    select:
        'id, household_id, transaction_id, storage_path, mime, size_bytes, created_by, created_at',
  ),
  BackupTable(
    name: 'fuel_logs',
    select:
        'id, household_id, vehicle_id, date, odometer_km::text, liters::text, total_cost::text, '
        'is_full, transaction_id, created_by, created_at',
    moneyColumns: {'total_cost'},
  ),
  BackupTable(
    name: 'maintenance_items',
    select:
        'id, household_id, vehicle_id, name, due_date, due_odometer_km::text, interval_days, '
        'interval_km::text, completed_at, created_at',
  ),
  BackupTable(
    name: 'pet_reminders',
    select:
        'id, household_id, pet_id, title, kind, due_date, repeat_months, done_at, created_by, created_at',
  ),
  BackupTable(
    name: 'budgets',
    select: 'id, household_id, category_id, amount::text, period, created_at, is_active',
    moneyColumns: {'amount'},
  ),
];

/// Tables that carry household data but are deliberately left out of the
/// backup, each with the reason (the manifest and `docs/backup.md` print it).
const Map<String, String> backupExcludedTables = <String, String>{
  'invites': 'Invite codes are bearer credentials (access tokens), not '
      'household data. Exporting one would hand out access to the household.',
};

/// Table name -> [BackupTable], for the exporter's dispatch.
final Map<String, BackupTable> backupTablesByName = <String, BackupTable>{
  for (final table in backupTables) table.name: table,
};

/// Every table the completeness check must find registered somewhere.
Set<String> get backupRegisteredTables => <String>{
      ...backupTables.map((table) => table.name),
      ...backupExcludedTables.keys,
    };
