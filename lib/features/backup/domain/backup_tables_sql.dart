import 'backup_tables.dart';

/// Renders the registry the Docker completeness check reads.
///
/// Kept here (not inside the generator) so `test/backup_tables_test.dart` can
/// rebuild it and prove the committed
/// `supabase/tests/support/backup_tables.generated.sql` is in sync with
/// [backupTables] / [backupExcludedTables]. That is what stops the exporter and
/// the check from drifting.
///
/// Two temp tables are emitted:
///   * `backup_table_registry` - every public table, exported or excluded.
///   * `backup_text_columns`   - the numeric columns the exporter reads as
///     `::text` (money + quantities). The check refuses when an exported table
///     has a `numeric` column the exporter would read as a float.
String buildBackupRegistrySql() {
  final buffer = StringBuffer()
    ..writeln('-- GENERATED FILE - DO NOT EDIT. Source of truth:')
    ..writeln('-- lib/features/backup/domain/backup_tables.dart, rendered by')
    ..writeln('-- tool/gen_backup_tables_sql.dart. tool/docker/validate.sh prepends')
    ..writeln('-- this to supabase/tests/support/check_backup_tables.sql.')
    ..writeln('drop table if exists backup_table_registry;')
    ..writeln('create temp table backup_table_registry (')
    ..writeln('  table_name text primary key,')
    ..writeln('  disposition text not null '
        "check (disposition in ('exported', 'excluded')),")
    ..writeln('  reason text')
    ..writeln(');')
    ..writeln(
        'insert into backup_table_registry (table_name, disposition, reason) values');

  final rows = <String>[
    for (final table in backupTables) "  ('${table.name}', 'exported', null)",
    for (final entry in backupExcludedTables.entries)
      "  ('${entry.key}', 'excluded', ${_sqlString(entry.value)})",
  ];
  buffer
    ..writeln('${rows.join(',\n')};')
    ..writeln('drop table if exists backup_text_columns;')
    ..writeln('create temp table backup_text_columns (')
    ..writeln('  table_name text not null,')
    ..writeln('  column_name text not null,')
    ..writeln('  primary key (table_name, column_name)')
    ..writeln(');')
    ..writeln('insert into backup_text_columns (table_name, column_name) values');

  final textRows = <String>[
    for (final table in backupTables)
      for (final column in textCastColumns(table.select))
        "  ('${table.name}', '$column')",
  ];
  buffer.writeln('${textRows.join(',\n')};');
  return buffer.toString();
}

/// Numeric columns the exporter reads through `::text` (money + quantities).
/// Parsed from the select so the generator cannot disagree with the exporter.
Iterable<String> textCastColumns(String select) sync* {
  for (final raw in select.split(',')) {
    final token = raw.trim();
    if (!token.endsWith('::text')) continue;
    yield token
        .substring(0, token.length - '::text'.length)
        .trim()
        .replaceAll('"', '');
  }
}

String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";
