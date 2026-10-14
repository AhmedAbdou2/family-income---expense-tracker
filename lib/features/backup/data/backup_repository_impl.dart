import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/backup_repository.dart';
import '../domain/backup_tables.dart';

/// The private bucket receipts live in (shared with the receipts feature).
const String backupReceiptsBucket = 'receipts';

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required BackupTable table,
    required String householdId,
    required int offset,
    required int limit,
  }) async {
    try {
      PostgrestTransformBuilder<PostgrestList> query = _client
          .from(table.name)
          .select(table.select)
          .eq(table.filterColumn, householdId);
      for (final column in table.orderColumns) {
        query = query.order(column, ascending: true);
      }
      final rows = await query.range(offset, offset + limit - 1);
      return rows.map(Map<String, dynamic>.from).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<List<int>> downloadReceipt(String storagePath) async {
    try {
      final data = await _client.storage
          .from(backupReceiptsBucket)
          .download(storagePath);
      return Uint8List.fromList(data);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
