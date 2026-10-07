import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../data/members_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/members_repository.dart';

final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// People of the current household. A child's RLS narrows this to their
/// own row, so every screen must render an empty list gracefully.
final membersProvider = FutureProvider<List<Member>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Member>[];
  return ref
      .watch(membersRepositoryProvider)
      .listMembers(householdId: membership.household.id);
});
