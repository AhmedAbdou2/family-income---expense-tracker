import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/receipts_repository.dart';

/// Metadata only - the bytes live in Storage under `storage_path`.
const _columns =
    'id, transaction_id, storage_path, mime, size_bytes, created_at';

/// The private bucket every receipt lives in.
const String receiptsBucket = 'receipts';

/// Signed URLs are short-lived on purpose: the bucket is private, so a URL
/// that leaks is useless within the hour.
const int receiptSignedUrlSeconds = 3600;

class ReceiptsRepositoryImpl implements ReceiptsRepository {
  ReceiptsRepositoryImpl(this._client);

  final SupabaseClient _client;

  Receipt _map(Map<String, dynamic> row) => Receipt(
        id: row['id'] as String,
        transactionId: row['transaction_id'] as String,
        storagePath: row['storage_path'] as String,
        mime: row['mime'] as String,
        sizeBytes: (row['size_bytes'] as num).toInt(),
        createdAt: row['created_at'] == null
            ? null
            : DateTime.parse(row['created_at'] as String),
      );

  @override
  Future<List<Receipt>> listReceipts({required String transactionId}) async {
    try {
      final rows = await _client
          .from('transaction_receipts')
          .select(_columns)
          .eq('transaction_id', transactionId)
          .order('created_at', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Receipt> uploadReceipt({
    required String transactionId,
    required ReceiptUpload upload,
  }) async {
    // Mirror the bucket rules before spending bandwidth; the server
    // re-checks them anyway (path, mime, size, 3-per-transaction cap).
    if (!isAllowedReceiptMime(upload.mime)) {
      throw const AppException(AppErrorCode.invalidMime);
    }
    if (!isAllowedReceiptSize(upload.sizeBytes)) {
      throw const AppException(AppErrorCode.invalidValue);
    }

    String? path;
    try {
      // 1. the server decides where the file may live
      path = await _client.rpc(
        'request_receipt_upload',
        params: {
          'p_transaction_id': transactionId,
          'p_mime': upload.mime,
          'p_size': upload.sizeBytes,
        },
      ) as String;

      // 2. put the bytes there
      await _client.storage.from(receiptsBucket).uploadBinary(
            path,
            Uint8List.fromList(upload.bytes),
            fileOptions: FileOptions(contentType: upload.mime),
          );

      // 3. record the metadata row (the object is re-validated server-side)
      final id = await _client.rpc(
        'attach_receipt',
        params: {
          'p_transaction_id': transactionId,
          'p_path': path,
          'p_mime': upload.mime,
          'p_size': upload.sizeBytes,
        },
      ) as String;

      return Receipt(
        id: id,
        transactionId: transactionId,
        storagePath: path,
        mime: upload.mime,
        sizeBytes: upload.sizeBytes,
      );
    } catch (error) {
      // Never leave a stray object behind when the attach step failed.
      if (path != null) {
        await _removeQuietly([path]);
      }
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteReceipt({required Receipt receipt}) async {
    try {
      final path = await _client.rpc(
        'delete_receipt',
        params: {'p_receipt_id': receipt.id},
      ) as String?;
      // The row is gone; the object may already have been swept away.
      await _removeQuietly([path ?? receipt.storagePath]);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<List<String>> listOrphanPaths() async {
    try {
      final rows = await _client.rpc('list_orphan_receipts');
      return (rows as List<dynamic>).cast<String>();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteObjects(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(receiptsBucket).remove(paths);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<String> signedUrl({required String storagePath}) async {
    try {
      return await _client.storage
          .from(receiptsBucket)
          .createSignedUrl(storagePath, receiptSignedUrlSeconds);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  /// Best-effort object removal used while already handling a failure: a
  /// storage hiccup here must not hide the original error.
  Future<void> _removeQuietly(List<String> paths) async {
    try {
      await _client.storage.from(receiptsBucket).remove(paths);
    } catch (_) {
      // ignored on purpose
    }
  }
}
