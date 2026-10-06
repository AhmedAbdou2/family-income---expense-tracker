import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/providers.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/household/presentation/create_household_screen.dart';
import '../../features/household/presentation/dashboard_screen.dart';
import '../../features/household/presentation/home_shell.dart';
import '../../features/household/presentation/join_household_screen.dart';
import '../../features/household/presentation/providers.dart';
import '../../features/household/presentation/setup_screen.dart';
import '../../features/household/presentation/splash_screen.dart';
import '../../features/household/presentation/transactions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'redirect.dart';

export 'redirect.dart';

/// Bridges Riverpod state changes into go_router's refresh mechanism: any
/// auth or household-membership update re-runs the redirect logic.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  final authSubscription =
      ref.listen(authStateProvider, (_, _) => refresh.notify());
  final membershipSubscription =
      ref.listen(membershipProvider, (_, _) => refresh.notify());
  ref.onDispose(() {
    authSubscription.close();
    membershipSubscription.close();
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: splashRoute,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final membership = ref.read(membershipProvider);
      return appRedirect(
        authLoading: auth.isLoading,
        signedIn: auth.value != null,
        membershipLoading: membership.isLoading,
        hasMembership: membership.value != null,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: splashRoute, builder: (context, state) => const SplashScreen()),

      // Authentication
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Household setup (create or join)
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(
        path: '/setup/create',
        builder: (context, state) => const CreateHouseholdScreen(),
      ),
      GoRoute(
        path: '/setup/join',
        builder: (context, state) => const JoinHouseholdScreen(),
      ),

      // Main shell: bottom nav on mobile, side rail on web/desktop
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
