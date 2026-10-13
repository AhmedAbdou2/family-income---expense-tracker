import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../data/receipts_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/receipts_repository.dart';

final receiptsRepositoryProvider = Provider<ReceiptsRepository>(
  (ref) => ReceiptsRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Receipts of one transaction (family key = transaction id). RLS returns
/// an empty list for a child, so the section simply stays hidden/empty.
final transactionReceiptsProvider =
    FutureProvider.family<List<Receipt>, String>((ref, transactionId) {
  return ref
      .watch(receiptsRepositoryProvider)
      .listReceipts(transactionId: transactionId);
});

/// Short-lived signed URL for one object (family key = storage path). The
/// bucket is private, so this is the only way to see the bytes.
final receiptSignedUrlProvider = FutureProvider.family<String, String>(
  (ref, storagePath) =>
      ref.watch(receiptsRepositoryProvider).signedUrl(storagePath: storagePath),
);
