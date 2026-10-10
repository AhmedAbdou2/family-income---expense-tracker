import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../data/recurring_rules_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/recurring_rules_repository.dart';

final recurringRulesRepositoryProvider = Provider<RecurringRulesRepository>(
  (ref) => RecurringRulesRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Recurring rules of the current household (adult-only via RLS).
final recurringRulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <RecurringRule>[];
  return ref
      .watch(recurringRulesRepositoryProvider)
      .listRules(householdId: membership.household.id);
});
