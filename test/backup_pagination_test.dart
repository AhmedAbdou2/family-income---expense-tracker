import 'package:family_income_expense_tracker/features/backup/data/backup_service.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_repository.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_tables.dart';
import 'package:flutter_test/flutter_test.dart';

/// PostgREST caps any single response at ~1000 rows. Every backup table is
/// paged, so each one must prove the boundary: 1000 rows arrive in one page,
/// 1001 rows arrive in two pages with no row dropped or repeated.
Map<String, dynamic> _row(String table, int index) => {
      'id': '$table-$index',
      'household_id': 'h1',
    };

class _FakeSource {
  _FakeSource(this.total);

  final int total;
  final List<int> offsets = [];

  Future<List<Map<String, dynamic>>> fetch(String table, int offset) async {
    offsets.add(offset);
    final remaining = total - offset;
    if (remaining <= 0) return const [];
    final count = remaining < backupPageSize ? remaining : backupPageSize;
    return [for (var i = 0; i < count; i++) _row(table, offset + i)];
  }
}

void main() {
  for (final table in backupTables) {
    group('${table.name} paging', () {
      test('1000 rows arrive in a single page', () async {
        final source = _FakeSource(1000);
        final rows = await collectBackupPages(
          table: table,
          householdId: 'h1',
          fetchPage: (offset) => source.fetch(table.name, offset),
        );
        expect(rows, hasLength(1000));
        expect(source.offsets, [0, 1000]);
      });

      test('1001 rows arrive complete across two pages', () async {
        final source = _FakeSource(1001);
        final rows = await collectBackupPages(
          table: table,
          householdId: 'h1',
          fetchPage: (offset) => source.fetch(table.name, offset),
        );
        expect(rows, hasLength(1001));
        // No duplicates and no gaps.
        expect(rows.map((row) => row['id']).toSet(), hasLength(1001));
        // 0 -> 1000 rows (full page), 1000 -> 1 row (short page ends the walk).
        expect(source.offsets, [0, backupPageSize]);
      });

      test('an empty table needs exactly one request', () async {
        final source = _FakeSource(0);
        final rows = await collectBackupPages(
          table: table,
          householdId: 'h1',
          fetchPage: (offset) => source.fetch(table.name, offset),
        );
        expect(rows, isEmpty);
        expect(source.offsets, [0]);
      });
    });
  }

  test('collectBackupPages keeps the order the source returns', () async {
    final source = _FakeSource(1001);
    final table = backupTablesByName['transactions']!;
    final rows = await collectBackupPages(
      table: table,
      householdId: 'h1',
      fetchPage: (offset) => source.fetch(table.name, offset),
    );
    expect(rows.first['id'], 'transactions-0');
    expect(rows.last['id'], 'transactions-1000');
  });
}
