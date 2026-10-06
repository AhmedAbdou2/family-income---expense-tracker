/// Authentication contract. The Supabase implementation lives in `data/`;
/// presentation code depends only on this interface (repository pattern).
abstract interface class AuthRepository {
  /// Emits the current user id, or null when signed out. First event is
  /// emitted once the persisted session has been resolved.
  Stream<String?> authStateChanges();

  String? get currentUserId;

  Future<void> signIn({required String email, required String password});

  Future<SignUpOutcome> signUp({required String email, required String password});

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}

enum SignUpOutcome { signedIn, confirmationEmailSent }
