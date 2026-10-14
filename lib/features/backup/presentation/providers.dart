import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../data/backup_repository_impl.dart';
import '../data/backup_service.dart';
import '../domain/backup_repository.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepositoryImpl(ref.watch(supabaseClientProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(backupRepositoryProvider)),
);

/// Sizes the receipt payload without downloading anything. Family key =
/// household id; invalidate to recompute (estimate screen retry).
final backupEstimateProvider =
    FutureProvider.family<BackupEstimate, String>((ref, householdId) {
  return ref.watch(backupServiceProvider).estimate(householdId);
});
