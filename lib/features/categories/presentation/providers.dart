import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../data/categories_repository_impl.dart';
import '../domain/categories_repository.dart';
import '../domain/entities.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Bilingual default categories (+ any custom ones) of the household.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Category>[];
  return ref
      .watch(categoriesRepositoryProvider)
      .listCategories(householdId: membership.household.id);
});
