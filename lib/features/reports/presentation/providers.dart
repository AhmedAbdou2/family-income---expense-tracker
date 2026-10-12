import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../data/reports_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/report_data.dart';
import '../domain/reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Income/expense per month for the 6-month window ending at the SHARED
/// dashboard month, aggregated by the `monthly_totals` RPC (adult-only).
final monthlyTotalsProvider = FutureProvider<List<MonthlyTotal>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <MonthlyTotal>[];
  final month = ref.watch(dashboardMonthProvider);
  final start = DateTime(month.year, month.month - 5);
  final end = DateTime(month.year, month.month + 1);
  return ref.watch(reportsRepositoryProvider).monthlyTotals(
        householdId: membership.household.id,
        startMonth: start,
        endMonthExclusive: end,
      );
});

/// The whole Reports screen's data for the selected month. Category and
/// person charts come from the same month rows the dashboard sums, so the
/// totals match the dashboard exactly.
final reportDataProvider = FutureProvider<ReportData>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) {
    return const ReportData(
      byCategory: <ReportSlice>[],
      byPerson: <ReportSlice>[],
      trend: <MonthlyTotal>[],
    );
  }
  final month = ref.watch(dashboardMonthProvider);
  final transactions =
      await ref.watch(dashboardMonthTransactionsProvider.future);
  final totals = await ref.watch(monthlyTotalsProvider.future);
  return buildReportData(
    monthTransactions: transactions,
    monthlyTotals: totals,
    endMonth: month,
  );
});
