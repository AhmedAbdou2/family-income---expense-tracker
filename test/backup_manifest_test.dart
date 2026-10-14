import 'dart:convert';

import 'package:family_income_expense_tracker/features/backup/domain/backup_archive.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_tables.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure checks for the archive JSON and the size decision. No database, no
/// widgets - these pin the shape `data.json` / `manifest.json` must have.
void main() {
  final txTable = backupTablesByName['transactions']!;

  test('money columns become integer minor units, never doubles', () {
    final json = backupRowToJson(
      table: txTable,
      row: {
        'id': 't1',
        'amount': '123.45',
        'odometer': '1200.5',
        'note': null,
      },
    );
    expect(json['amount_minor_units'], 12345);
    expect(json['amount_minor_units'], isA<int>());
    expect(json.containsKey('amount'), isFalse);
    // Quantities keep their exact decimal string (no float path).
    expect(json['odometer'], '1200.5');
    expect(json['odometer'], isA<String>());
    expect(json['note'], isNull);
  });

  test('data.json nests every table and keeps the household id', () {
    final now = DateTime.utc(2026, 10, 14, 9, 30);
    final decoded = jsonDecode(
      buildBackupDataJson(
        householdId: 'h1',
        generatedAt: now,
        tables: {
          'transactions': [
            {'id': 't1', 'amount': '10.00'},
          ],
        },
      ),
    ) as Map<String, dynamic>;

    expect(decoded['household_id'], 'h1');
    expect(decoded['generated_at'], now.toIso8601String());
    final tables = decoded['tables'] as Map<String, dynamic>;
    final rows = tables['transactions'] as List<dynamic>;
    expect((rows.single as Map)['amount_minor_units'], 1000);
  });

  test('manifest carries version, counts, exclusions and receipt status', () {
    final decoded = jsonDecode(
      buildBackupManifestJson(
        householdId: 'h1',
        generatedAt: DateTime.utc(2026, 10, 14),
        tables: {
          'transactions': [
            {'id': 't1'},
            {'id': 't2'},
          ],
        },
        receipts: const [
          ReceiptBackupEntry(
            storagePath: 'h1/t1/a.jpg',
            sizeBytes: 10,
            included: true,
          ),
          ReceiptBackupEntry(
            storagePath: 'h1/t1/b.jpg',
            sizeBytes: 20,
            included: false,
            reason: 'download_failed',
          ),
        ],
      ),
    ) as Map<String, dynamic>;

    expect(decoded['format_version'], backupFormatVersion);
    expect(decoded['schema_version'], backupSchemaVersion);
    final counts = decoded['counts'] as Map<String, dynamic>;
    expect(counts['transactions'], 2);
    // Every exported table appears in the counts (0 when empty).
    for (final table in backupTables) {
      expect(counts.containsKey(table.name), isTrue, reason: table.name);
    }
    final excluded = decoded['excluded_tables'] as Map<String, dynamic>;
    expect(excluded.keys, containsAll(backupExcludedTables.keys));
    final receipts = decoded['receipts'] as List<dynamic>;
    expect((receipts[0] as Map)['included'], true);
    expect((receipts[1] as Map)['included'], false);
    expect((receipts[1] as Map)['reason'], 'download_failed');
  });

  test('size decision respects the 100 MiB warn and 300 MiB refuse edges', () {
    expect(backupSizeStatus(0), BackupSizeStatus.ok);
    expect(backupSizeStatus(backupWarnReceiptBytes), BackupSizeStatus.ok);
    expect(backupSizeStatus(backupWarnReceiptBytes + 1), BackupSizeStatus.warn);
    expect(backupSizeStatus(backupMaxReceiptBytes), BackupSizeStatus.warn);
    expect(
      backupSizeStatus(backupMaxReceiptBytes + 1),
      BackupSizeStatus.refuse,
    );
  });

  test('formatByteSize reads as binary units', () {
    expect(formatByteSize(0), '0 B');
    expect(formatByteSize(512), '512 B');
    expect(formatByteSize(1024), '1.0 KB');
    expect(formatByteSize(1024 * 1024), '1.0 MB');
    expect(formatByteSize(300 * 1024 * 1024), '300.0 MB');
  });
}
