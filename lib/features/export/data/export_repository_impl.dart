import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../transactions/domain/entities.dart';
import '../domain/export_repository.dart';

/// PostgREST returns at most ~1000 rows per request (the cap also applies to
/// table-returning functions). Export pages through the window with
/// `.range()` so a year of data arrives complete instead of silently
/// truncated at the first 1000 rows.
const int exportPageSize = 1000;

/// Walks a paginated transaction read until a short page arrives.
///
/// `fetchPage(offset)` must apply the same filter and the same deterministic
/// ordering on every call - otherwise a page boundary inside one date could
/// drop or repeat a row. Taking the loader as a function keeps this loop
/// unit-testable without a database.
Future<List<Transaction>> collectTransactionPages({
  required Future<List<Map<String, dynamic>>> Function(int offset) fetchPage,
  int pageSize = exportPageSize,
}) async {
  final rows = <Transaction>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset);
    rows.addAll(page.map(transactionFromRow));
    // A short page is the only end-of-data signal PostgREST gives us.
    if (page.length < pageSize) return rows;
    offset += pageSize;
  }
}

class ExportRepositoryImpl implements ExportRepository {
  ExportRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Transaction>> fetchForExport({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      return await collectTransactionPages(
        fetchPage: (offset) => _client
            .from('transactions')
            .select(transactionColumns)
            .eq('household_id', householdId)
            .gte('date', _dateKey(from))
            .lte('date', _dateKey(to))
            // Deterministic order: without the id tiebreaker a page boundary
            // inside one date could drop or repeat a row.
            .order('date', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + exportPageSize - 1),
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
