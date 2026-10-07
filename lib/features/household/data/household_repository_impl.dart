import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/household_repository.dart';

class HouseholdRepositoryImpl implements HouseholdRepository {
  HouseholdRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Membership?> currentMembership() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final rows = await _client
          .from('household_users')
          .select('role, created_at, households(id, name, currency)')
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(1);
      if (rows.isEmpty) return null;

      final row = rows.first;
      final household = row['households'];
      if (household is! Map<String, dynamic>) return null;

      return Membership(
        household: Household(
          id: household['id'] as String,
          name: household['name'] as String,
          currency: household['currency'] as String,
        ),
        role: MemberRole.fromDb(row['role'] as String),
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> createHousehold({
    required String name,
    required String currency,
  }) async {
    try {
      await _client.rpc(
        'create_household',
        params: {'p_name': name.trim(), 'p_currency': currency},
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> acceptInvite({required String code}) async {
    try {
      await _client.rpc('accept_invite', params: {'p_code': code.trim()});
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<String> createInvite({
    required String householdId,
    required MemberRole role,
    int ttlDays = 7,
    String? memberId,
  }) async {
    try {
      final result = await _client.rpc(
        'create_invite',
        params: {
          'p_household_id': householdId,
          'p_role': role.dbValue,
          'p_ttl_days': ttlDays,
          'p_member_id': ?memberId,
        },
      );
      return result as String;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<List<Invite>> listInvites({required String householdId}) async {
    try {
      final rows = await _client
          .from('invites')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      return rows
          .map(
            (row) => Invite(
              id: row['id'] as String,
              code: row['code'] as String,
              role: MemberRole.fromDb(row['role'] as String),
              expiresAt: row['expires_at'] == null
                  ? null
                  : DateTime.parse(row['expires_at'] as String),
              usedBy: row['used_by'] as String?,
            ),
          )
          .toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
