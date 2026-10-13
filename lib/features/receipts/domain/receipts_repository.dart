import 'entities.dart';

/// Receipts of a transaction (owner/adult only).
///
/// Every write is server-side: the metadata table has no INSERT/UPDATE/
/// DELETE policy, so only the RPCs below (plus the Storage API for the
/// bytes) can change anything.
abstract interface class ReceiptsRepository {
  /// Receipts of [transactionId], oldest first.
  Future<List<Receipt>> listReceipts({required String transactionId});

  /// Three steps, in order:
  ///   1. `request_receipt_upload` mints the storage path server-side;
  ///   2. the bytes are uploaded to that exact path;
  ///   3. `attach_receipt` records the metadata row (and re-validates).
  ///
  /// If step 3 fails the object from step 2 is removed again, so a failed
  /// attach never leaves a stray file behind.
  Future<Receipt> uploadReceipt({
    required String transactionId,
    required ReceiptUpload upload,
  });

  /// Drops the metadata row and then the storage object. Tolerates a
  /// missing object (the row may already have been swept).
  Future<void> deleteReceipt({required Receipt receipt});

  /// Objects under the caller's household folder with no metadata row.
  /// Used by the self-heal sweep (a delete that died half-way).
  Future<List<String>> listOrphanPaths();

  /// Removes storage objects by path (used by the sweep and by the
  /// transaction/fuel/rule deletes that cascade receipts away).
  Future<void> deleteObjects(List<String> paths);

  /// Short-lived signed URL for viewing a private object.
  Future<String> signedUrl({required String storagePath});
}
