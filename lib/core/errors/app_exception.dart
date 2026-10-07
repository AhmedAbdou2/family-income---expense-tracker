import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Stable, UI-agnostic error codes. Presentation maps them to localized
/// strings - error messages are never shown to the user as-is.
enum AppErrorCode {
  network,
  timeout,
  invalidCredentials,
  emailExists,
  emailNotConfirmed,
  weakPassword,
  invalidEmail,
  tooManyRequests,
  inviteNotFound,
  inviteUsed,
  inviteExpired,
  alreadyMember,
  notMember,
  forbidden,
  invalidName,
  invalidCurrency,
  invalidRole,
  membershipImmutable,
  memberLinked,
  loginLinked,
  invalidMember,
  categoryInUse,
  memberInUse,
  unknown,
}

class AppException implements Exception {
  const AppException(this.code, {this.debugMessage});

  final AppErrorCode code;
  final String? debugMessage;

  @override
  String toString() =>
      'AppException($code${debugMessage == null ? '' : ': $debugMessage'})';
}

/// Translates every backend/network error into an [AppException].
/// Repositories call this before throwing so the UI only ever sees
/// [AppException].
abstract final class ExceptionMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) return _fromAuth(error);
    if (error is PostgrestException) return _fromPostgrest(error);
    if (error is TimeoutException) {
      return const AppException(AppErrorCode.timeout);
    }

    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network')) {
      return const AppException(AppErrorCode.network);
    }
    return AppException(AppErrorCode.unknown, debugMessage: error.toString());
  }

  static AppException _fromAuth(AuthException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    switch (code) {
      case 'invalid_credentials':
      case 'user_not_found':
        return const AppException(AppErrorCode.invalidCredentials);
      case 'user_already_exists':
        return const AppException(AppErrorCode.emailExists);
      case 'weak_password':
        return const AppException(AppErrorCode.weakPassword);
      case 'email_not_confirmed':
        return const AppException(AppErrorCode.emailNotConfirmed);
      case 'over_email_send_rate_limit':
      case 'email_rate_limit_exceeded':
      case 'rate_limit_exceeded':
        return const AppException(AppErrorCode.tooManyRequests);
      case 'validation_failed':
        if (message.contains('email')) {
          return const AppException(AppErrorCode.invalidEmail);
        }
        break;
    }

    if (message.contains('invalid login credentials')) {
      return const AppException(AppErrorCode.invalidCredentials);
    }
    if (message.contains('rate limit')) {
      return const AppException(AppErrorCode.tooManyRequests);
    }
    if (message.contains('email')) {
      return const AppException(AppErrorCode.invalidEmail);
    }
    return AppException(AppErrorCode.unknown, debugMessage: error.message);
  }

  static AppException _fromPostgrest(PostgrestException error) {
    // Keys raised by SECURITY DEFINER functions in /supabase/migrations.
    switch (error.message) {
      case 'invite_not_found':
        return const AppException(AppErrorCode.inviteNotFound);
      case 'invite_used':
        return const AppException(AppErrorCode.inviteUsed);
      case 'invite_expired':
        return const AppException(AppErrorCode.inviteExpired);
      case 'already_member':
        return const AppException(AppErrorCode.alreadyMember);
      case 'not_member':
        return const AppException(AppErrorCode.notMember);
      case 'forbidden':
      case 'membership_identity_immutable':
        return const AppException(AppErrorCode.forbidden);
      case 'invalid_name':
        return const AppException(AppErrorCode.invalidName);
      case 'invalid_currency':
        return const AppException(AppErrorCode.invalidCurrency);
      case 'invalid_role':
      case 'invalid_ttl':
        return const AppException(AppErrorCode.invalidRole);
      case 'not_authenticated':
        return const AppException(AppErrorCode.invalidCredentials);
      case 'member_linked':
        return const AppException(AppErrorCode.memberLinked);
      case 'login_linked':
        return const AppException(AppErrorCode.loginLinked);
      case 'invalid_member':
        return const AppException(AppErrorCode.invalidMember);
    }

    final message = error.message.toLowerCase();
    if (error.code == '23503') {
      // FK violations: transactions/ budgets/ recurring_rules keep the row
      // they point at (on delete restrict). Distinguish by constraint name.
      if (error.message.contains('category')) {
        return const AppException(AppErrorCode.categoryInUse);
      }
      if (error.message.contains('member')) {
        return const AppException(AppErrorCode.memberInUse);
      }
      return const AppException(AppErrorCode.forbidden);
    }
    if (message.contains('row-level security')) {
      return const AppException(AppErrorCode.forbidden);
    }
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const AppException(AppErrorCode.forbidden);
    }
    if (message.contains('fetch') ||
        message.contains('network') ||
        message.contains('failed host')) {
      return const AppException(AppErrorCode.network);
    }
    return AppException(
      AppErrorCode.unknown,
      debugMessage: '${error.code}: ${error.message}',
    );
  }
}
