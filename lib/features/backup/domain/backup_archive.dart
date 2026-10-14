import 'dart:convert';

import '../../../core/utils/money.dart';
import 'backup_tables.dart';

/// How big the receipt payload is, and what the UI should do about it.
enum BackupSizeStatus {
  /// Small enough to export quietly.
  ok,

  /// Above [backupWarnReceiptBytes]: ask the user before starting.
  warn,

  /// Above [backupMaxReceiptBytes]: refuse receipt bytes (data-only stays
  /// available) because the ZIP is assembled in memory on web.
  refuse,
}

/// The receipt bytes are estimated from `transaction_receipts.size_bytes`,
/// which is the size the object had when it was attached - close enough to
/// decide, and it costs one metadata read instead of downloading anything.
BackupSizeStatus backupSizeStatus(int receiptBytes) {
  if (receiptBytes > backupMaxReceiptBytes) return BackupSizeStatus.refuse;
  if (receiptBytes > backupWarnReceiptBytes) return BackupSizeStatus.warn;
  return BackupSizeStatus.ok;
}

/// One receipt object and whether it made it into the archive. A receipt that
/// could not be downloaded is recorded as missing - never fatal.
class ReceiptBackupEntry {
  const ReceiptBackupEntry({
    required this.storagePath,
    required this.sizeBytes,
    required this.included,
    this.reason,
  });

  final String storagePath;
  final int sizeBytes;
  final bool included;

  /// `download_failed`, `omitted_size_limit` or `omitted_data_only`.
  final String? reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'storage_path': storagePath,
        'size_bytes': sizeBytes,
        'included': included,
        if (reason != null) 'reason': reason,
      };
}

/// Converts one PostgREST row to the JSON the archive stores.
///
/// Money columns (already read as `numeric::text`) become `<column>_minor_units`
/// integers so every consumer stays in integer minor units. All other numeric
/// columns were cast to `text` in the select and are kept as exact decimal
/// strings - no float ever touches the data.
Map<String, dynamic> backupRowToJson({
  required BackupTable table,
  required Map<String, dynamic> row,
}) {
  final out = <String, dynamic>{};
  for (final entry in row.entries) {
    final key = entry.key;
    final value = entry.value;
    if (table.moneyColumns.contains(key)) {
      out['${key}_minor_units'] = value == null
          ? null
          : Money.decimalStringToMinorUnits(value.toString());
    } else {
      out[key] = value;
    }
  }
  return out;
}

Map<String, List<Map<String, dynamic>>> backupTablesToJson(
  Map<String, List<Map<String, dynamic>>> rows,
) =>
    <String, List<Map<String, dynamic>>>{
      for (final entry in rows.entries)
        entry.key: <Map<String, dynamic>>[
          for (final row in entry.value)
            backupRowToJson(
              table: backupTablesByName[entry.key]!,
              row: row,
            ),
        ],
    };

/// `data.json`: the household's rows, one array per table.
String buildBackupDataJson({
  required String householdId,
  required DateTime generatedAt,
  required Map<String, List<Map<String, dynamic>>> tables,
}) =>
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'household_id': householdId,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'tables': backupTablesToJson(tables),
    });

/// `manifest.json`: what the archive holds, what it leaves out and why.
String buildBackupManifestJson({
  required String householdId,
  required DateTime generatedAt,
  required Map<String, List<Map<String, dynamic>>> tables,
  required List<ReceiptBackupEntry> receipts,
}) =>
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'format_version': backupFormatVersion,
      'schema_version': backupSchemaVersion,
      'household_id': householdId,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'counts': <String, int>{
        for (final table in backupTables)
          table.name: tables[table.name]?.length ?? 0,
      },
      'excluded_tables': backupExcludedTables,
      'receipts': <Map<String, dynamic>>[
        for (final receipt in receipts) receipt.toJson(),
      ],
    });

/// A human-readable byte size for the UI (binary units, one decimal).
String formatByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}
