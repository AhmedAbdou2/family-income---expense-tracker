import 'backup_tables.dart';

/// Reads the raw rows a household backup needs, plus receipt objects.
///
/// Everything goes through the caller's own RLS view, so a backup can only
/// ever contain the household the owner belongs to.
abstract interface class BackupRepository {
  /// One page of [table] for [householdId], using the table's deterministic
  /// ordering. `limit` is normally [backupPageSize] (1000) so the loop can
  /// detect the end of the data with a short page.
  Future<List<Map<String, dynamic>>> fetchPage({
    required BackupTable table,
    required String householdId,
    required int offset,
    required int limit,
  });

  /// Downloads one receipt object's bytes through the Storage API.
  Future<List<int>> downloadReceipt(String storagePath);
}

/// PostgREST caps any single response at ~1000 rows, so every table is paged.
const int backupPageSize = 1000;
