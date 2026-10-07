import 'package:family_income_expense_tracker/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ExceptionMapper', () {
    test('maps RPC error keys raised by our migrations', () {
      const cases = <String, AppErrorCode>{
        'invite_not_found': AppErrorCode.inviteNotFound,
        'invite_used': AppErrorCode.inviteUsed,
        'invite_expired': AppErrorCode.inviteExpired,
        'already_member': AppErrorCode.alreadyMember,
        'not_member': AppErrorCode.notMember,
        'forbidden': AppErrorCode.forbidden,
        'membership_identity_immutable': AppErrorCode.forbidden,
        'invalid_name': AppErrorCode.invalidName,
        'invalid_currency': AppErrorCode.invalidCurrency,
        'not_authenticated': AppErrorCode.invalidCredentials,
        'member_linked': AppErrorCode.memberLinked,
        'login_linked': AppErrorCode.loginLinked,
        'invalid_member': AppErrorCode.invalidMember,
      };

      cases.forEach((message, expected) {
        final mapped = ExceptionMapper.map(
          PostgrestException(message: message, code: 'P0001'),
        );
        expect(mapped.code, expected, reason: message);
      });
    });

    test('maps Postgres RLS violations to forbidden', () {
      final mapped = ExceptionMapper.map(
        const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      );
      expect(mapped.code, AppErrorCode.forbidden);
    });

    test('maps FK (23503) restrict violations by constraint name', () {
      expect(
        ExceptionMapper.map(const PostgrestException(
          message:
              'insert or update on table "transactions" violates foreign '
              'key constraint "transactions_category_id_fkey"',
          code: '23503',
        )).code,
        AppErrorCode.categoryInUse,
      );
      expect(
        ExceptionMapper.map(const PostgrestException(
          message:
              'update or delete on table "members" violates foreign '
              'key constraint "transactions_member_id_fkey"',
          code: '23503',
        )).code,
        AppErrorCode.memberInUse,
      );
      expect(
        ExceptionMapper.map(const PostgrestException(
          message: 'violates foreign key constraint "something_else_fkey"',
          code: '23503',
        )).code,
        AppErrorCode.forbidden,
      );
    });

    test('maps auth error codes', () {
      expect(
        ExceptionMapper.map(const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        )).code,
        AppErrorCode.invalidCredentials,
      );
      expect(
        ExceptionMapper.map(const AuthException(
          'User already registered',
          code: 'user_already_exists',
        )).code,
        AppErrorCode.emailExists,
      );
      expect(
        ExceptionMapper.map(const AuthException(
          'Password should be at least 6 characters',
          code: 'weak_password',
        )).code,
        AppErrorCode.weakPassword,
      );
    });

    test('maps network-ish failures', () {
      expect(
        ExceptionMapper.map(const SocketExceptionLike()).code,
        AppErrorCode.network,
      );
      expect(
        ExceptionMapper.map(Exception('clientexception: Failed host lookup')).code,
        AppErrorCode.network,
      );
    });

    test('passes AppException through untouched', () {
      const original = AppException(AppErrorCode.timeout);
      expect(ExceptionMapper.map(original), same(original));
    });

    test('falls back to unknown', () {
      final mapped = ExceptionMapper.map(StateError('boom'));
      expect(mapped.code, AppErrorCode.unknown);
      expect(mapped.debugMessage, contains('boom'));
    });
  });
}

/// Simulates the string form of a dart:io SocketException without importing
/// dart:io (which would break web compilation of this test file).
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();

  @override
  String toString() => 'SocketException: Connection refused (OS Error: 111)';
}
