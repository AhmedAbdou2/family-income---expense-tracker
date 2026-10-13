import '../../transactions/domain/entities.dart';

/// Reads transactions for export.
///
/// A separate repository (rather than reusing the month list) because an
/// export covers an arbitrary window and can be far larger than a month.
abstract interface class ExportRepository {
  /// Every transaction of [householdId] with a date in [from]..[to]
  /// (inclusive), newest first.
  ///
  /// PAGINATED ON PURPOSE: PostgREST caps a single response at ~1000 rows
  /// (the same cap applies to table-returning RPCs), so the implementation
  /// walks the window with `.range()` pages and stitches them together.
  Future<List<Transaction>> fetchForExport({
    required String householdId,
    required DateTime from,
    required DateTime to,
  });
}