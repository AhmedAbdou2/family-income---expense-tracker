import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<String?> authStateChanges() =>
      _client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response.session == null
          ? SignUpOutcome.confirmationEmailSent
          : SignUpOutcome.signedIn;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        // Reuse the web hosting URL if configured; the app itself opens the
        // reset link externally. Phase 5 may add deep links.
        redirectTo: Uri.base.hasScheme && Uri.base.host.isNotEmpty
            ? Uri.base.origin
            : null,
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
