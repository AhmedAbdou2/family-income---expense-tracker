import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._client);

  final SupabaseClient _client;

  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Future<List<MonthlyTotal>> monthlyTotals({
    required String householdId,
    required DateTime startMonth,
    required DateTime endMonthExclusive,
  }) async {
    try {
      final rows = await _client.rpc(
        'monthly_totals',
        params: {
          'p_household_id': householdId,
          'p_start_month': _dateKey(startMonth),
          'p_end_month': _dateKey(endMonthExclusive),
        },
      );
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => MonthlyTotal(
              month: DateTime.parse(row['month_start'] as String),
              incomeMinor: (row['income_minor'] as num).toInt(),
              expenseMinor: (row['expense_minor'] as num).toInt(),
            ),
          )
          .toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
