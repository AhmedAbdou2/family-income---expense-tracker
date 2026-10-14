import 'dart:io';

import 'package:family_income_expense_tracker/features/backup/domain/backup_tables.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_tables_sql.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backup exporter and the Docker completeness check share ONE source of
/// truth: `lib/features/backup/domain/backup_tables.dart`. These tests keep the
/// committed SQL in sync with it and pin the invariants the exporter relies on,
/// so the two can never drift silently.
void main() {
  Map<String, Object?> loadManifest() =>
      {'exported': backupTables, 'excluded': backupExcludedTables};

  test('the generated registry SQL is in sync with the Dart source of truth',
      () {
    final actual = File('supabase/tests/support/backup_tables.generated.sql')
        .readAsStringSync();
    expect(
      actual,
      buildBackupRegistrySql(),
      reason: 'run: dart run tool/gen_backup_tables_sql.dart',
    );
  });

  test('a table is never both exported and excluded', () {
    final exported = backupTables.map((table) => table.name).toSet();
    final excluded = backupExcludedTables.keys.toSet();
    expect(exported.intersection(excluded), isEmpty);
    // No duplicate export entries either.
    expect(exported.length, backupTables.length);
  });

  test('every exclusion carries a non-empty reason', () {
    for (final entry in backupExcludedTables.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('every exported table declares a filter and at least one order column',
      () {
    for (final table in backupTables) {
      expect(table.filterColumn, isNotEmpty, reason: table.name);
      expect(table.orderColumns, isNotEmpty, reason: table.name);
    }
  });

  test('money columns are cast to ::text in the select', () {
    for (final table in backupTables) {
      for (final column in table.moneyColumns) {
        expect(
          textCastColumns(table.select),
          contains(column),
          reason: '${table.name}.$column must be read via ::text',
        );
      }
    }
  });

  test('backupSchemaVersion matches the migration file count', () {
    final count = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .length;
    expect(
      backupSchemaVersion,
      count,
      reason: 'bump backupSchemaVersion when a migration is added',
    );
  });

  test('the shared manifest exposes what the check expects', () {
    // Guards the shape both sides read: the regenerated SQL must name every
    // exported table and the excluded one.
    final sql = buildBackupRegistrySql();
    for (final table in backupTables) {
      expect(sql, contains("('${table.name}', 'exported'"));
    }
    for (final table in backupExcludedTables.keys) {
      expect(sql, contains("('$table', 'excluded'"));
    }
    expect(loadManifest()['exported'], isA<List<BackupTable>>());
  });
}
