import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Signed-in user id (null when signed out). First value arrives once
/// Supabase has resolved any persisted session - until then the provider
/// is loading and the router shows the splash screen.
final authStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
