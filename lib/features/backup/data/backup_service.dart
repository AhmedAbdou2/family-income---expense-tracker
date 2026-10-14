import 'dart:convert';
import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../domain/backup_archive.dart';
import '../domain/backup_repository.dart';
import '../domain/backup_tables.dart';
import '../domain/backup_zip.dart';

/// Walks a paginated backup read until a short page arrives.
///
/// `fetchPage(offset)` must apply the same filter and the same deterministic
/// ordering on every call - otherwise a page boundary inside one key could
/// drop or repeat a row. Taking the loader as a function keeps this loop
/// unit-testable for every table without a database.
Future<List<Map<String, dynamic>>> collectBackupPages({
  required BackupTable table,
  required String householdId,
  required Future<List<Map<String, dynamic>>> Function(int offset) fetchPage,
  int pageSize = backupPageSize,
}) async {
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset);
    rows.addAll(page);
    // A short page is the only end-of-data signal PostgREST gives us.
    if (page.length < pageSize) return rows;
    offset += pageSize;
  }
}

/// What the receipt estimate says before a backup starts.
class BackupEstimate {
  const BackupEstimate({required this.receiptCount, required this.receiptBytes});

  final int receiptCount;
  final int receiptBytes;

  BackupSizeStatus get status => backupSizeStatus(receiptBytes);
}

/// The finished archive and a small summary for the UI/report.
class BackupOutcome {
  const BackupOutcome({
    required this.zipBytes,
    required this.fileName,
    required this.tableCounts,
    required this.receiptsIncluded,
    required this.receiptsMissing,
  });

  final Uint8List zipBytes;
  final String fileName;
  final Map<String, int> tableCounts;
  final int receiptsIncluded;
  final int receiptsMissing;
}

/// Drives a full household backup: read every table (paged), optionally
/// download every receipt, then pack the ZIP. All heavy lifting is here so the
/// widget only shows progress and saves the bytes.
class BackupService {
  BackupService(this._repository);

  final BackupRepository _repository;

  /// Reads only the receipt metadata to size the payload. Nothing is
  /// downloaded, so this is cheap even for a large household.
  Future<BackupEstimate> estimate(String householdId) async {
    final receipts = await _fetchTable('transaction_receipts', householdId);
    var bytes = 0;
    for (final row in receipts) {
      bytes += (row['size_bytes'] as num?)?.toInt() ?? 0;
    }
    return BackupEstimate(receiptCount: receipts.length, receiptBytes: bytes);
  }

  /// Builds the archive.
  ///
  /// [includeReceipts] false skips every object (data-only), marking each
  /// entry `omitted_data_only`. A receipt that cannot be downloaded is marked
  /// `download_failed` and the export continues - one bad object never fails
  /// the whole backup.
  Future<BackupOutcome> run({
    required String householdId,
    required bool includeReceipts,
    DateTime? now,
    void Function(int done, int total)? onTableProgress,
    void Function(int done, int total)? onReceiptProgress,
  }) async {
    final generatedAt = (now ?? DateTime.now()).toUtc();

    final tables = <String, List<Map<String, dynamic>>>{};
    var tableIndex = 0;
    for (final table in backupTables) {
      tables[table.name] = await _fetchTable(table.name, householdId);
      tableIndex++;
      onTableProgress?.call(tableIndex, backupTables.length);
    }

    // Receipt metadata drives both the download list and the manifest.
    final receiptRows = tables['transaction_receipts'] ?? const [];
    final entries = <ReceiptBackupEntry>[];
    final blobs = <BackupReceiptBlob>[];

    // Defense in depth: the screen refuses above the hard cap first, but a
    // direct call must not try to assemble a ZIP that could kill the tab.
    if (includeReceipts) {
      var receiptBytes = 0;
      for (final row in receiptRows) {
        receiptBytes += (row['size_bytes'] as num?)?.toInt() ?? 0;
      }
      if (backupSizeStatus(receiptBytes) == BackupSizeStatus.refuse) {
        throw const AppException(AppErrorCode.backupTooLarge);
      }
    }

    var done = 0;
    for (final row in receiptRows) {
      final path = row['storage_path'] as String;
      final size = (row['size_bytes'] as num?)?.toInt() ?? 0;
      if (!includeReceipts) {
        entries.add(ReceiptBackupEntry(
          storagePath: path,
          sizeBytes: size,
          included: false,
          reason: 'omitted_data_only',
        ));
      } else {
        try {
          final bytes = await _repository.downloadReceipt(path);
          blobs.add(BackupReceiptBlob(storagePath: path, bytes: bytes));
          entries.add(ReceiptBackupEntry(
            storagePath: path,
            sizeBytes: size,
            included: true,
          ));
        } catch (_) {
          entries.add(ReceiptBackupEntry(
            storagePath: path,
            sizeBytes: size,
            included: false,
            reason: 'download_failed',
          ));
        }
      }
      done++;
      onReceiptProgress?.call(done, receiptRows.length);
    }

    final dataJson = buildBackupDataJson(
      householdId: householdId,
      generatedAt: generatedAt,
      tables: tables,
    );
    final manifestJson = buildBackupManifestJson(
      householdId: householdId,
      generatedAt: generatedAt,
      tables: tables,
      receipts: entries,
    );

    final zipBytes = buildBackupZip(
      dataJson: utf8.encode(dataJson),
      manifestJson: utf8.encode(manifestJson),
      receipts: blobs,
    );

    return BackupOutcome(
      zipBytes: zipBytes,
      fileName: _fileName(generatedAt),
      tableCounts: <String, int>{
        for (final table in backupTables) table.name: tables[table.name]!.length,
      },
      receiptsIncluded: entries.where((entry) => entry.included).length,
      receiptsMissing:
          entries.where((entry) => !entry.included && entry.reason == 'download_failed').length,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTable(
    String tableName,
    String householdId,
  ) async {
    final table = backupTablesByName[tableName]!;
    try {
      return await collectBackupPages(
        table: table,
        householdId: householdId,
        fetchPage: (offset) => _repository.fetchPage(
          table: table,
          householdId: householdId,
          offset: offset,
          limit: backupPageSize,
        ),
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  String _fileName(DateTime utc) {
    final stamp = '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}-'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}';
    return 'household-backup-$stamp.zip';
  }
}
