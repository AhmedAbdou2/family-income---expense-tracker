import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/members_repository.dart';

class MembersRepositoryImpl implements MembersRepository {
  MembersRepositoryImpl(this._client);

  final SupabaseClient _client;

  Member _map(Map<String, dynamic> row) => Member(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        name: row['name'] as String,
        isActive: row['is_active'] as bool? ?? true,
        avatar: row['avatar'] as String?,
        userId: row['user_id'] as String?,
      );

  @override
  Future<List<Member>> listMembers({required String householdId}) async {
    try {
      final rows = await _client
          .from('members')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Member> createMember({
    required String householdId,
    required String name,
  }) async {
    try {
      final row = await _client
          .from('members')
          .insert({'household_id': householdId, 'name': name.trim()})
          .select()
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> renameMember({
    required String memberId,
    required String name,
  }) async {
    try {
      await _client.rpc(
        'rename_member',
        params: {'p_member_id': memberId, 'p_display_name': name.trim()},
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<bool> hasLinkedPerson({required String householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final rows = await _client
          .from('members')
          .select('id')
          .eq('household_id', householdId)
          .eq('user_id', userId)
          .limit(1);
      return rows.isNotEmpty;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> setMemberActive({
    required String memberId,
    required bool isActive,
  }) async {
    try {
      await _client
          .from('members')
          .update({'is_active': isActive}).eq('id', memberId);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteMember({required String memberId}) async {
    try {
      await _client.from('members').delete().eq('id', memberId);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
