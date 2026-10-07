import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../data/transactions_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/transactions_repository.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// First day of the month being viewed. Dashboard and the transactions
/// list keep independent state so tab switching never hides your place.
class MonthController extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime(DateTime.now().year, DateTime.now().month);

  void previous() =>
      state = DateTime(state.year, state.month - 1, 1);

  void next() => state = DateTime(state.year, state.month + 1, 1);
}

final dashboardMonthProvider = NotifierProvider<MonthController, DateTime>(
  MonthController.new,
);

final transactionsMonthProvider = NotifierProvider<MonthController, DateTime>(
  MonthController.new,
);

/// Person filter on the transactions list. null = everyone.
class MemberFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? memberId) => state = memberId;
}

final transactionsMemberFilterProvider =
    NotifierProvider<MemberFilterController, String?>(
  MemberFilterController.new,
);

final monthTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final membership = ref.watch(membershipProvider).value;
  final month = ref.watch(transactionsMonthProvider);
  final memberId = ref.watch(transactionsMemberFilterProvider);
  if (membership == null) return const <Transaction>[];
  return ref.watch(transactionsRepositoryProvider).listTransactions(
        householdId: membership.household.id,
        month: month,
        memberId: memberId,
      );
});

final dashboardMonthTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final membership = ref.watch(membershipProvider).value;
  final month = ref.watch(dashboardMonthProvider);
  if (membership == null) return const <Transaction>[];
  return ref.watch(transactionsRepositoryProvider).listTransactions(
        householdId: membership.household.id,
        month: month,
      );
});
