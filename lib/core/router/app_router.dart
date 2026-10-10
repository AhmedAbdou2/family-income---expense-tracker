import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/providers.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/household/presentation/claim_screen.dart';
import '../../features/household/presentation/create_household_screen.dart';
import '../../features/household/presentation/dashboard_screen.dart';
import '../../features/household/presentation/home_shell.dart';
import '../../features/household/presentation/household_members_screen.dart';
import '../../features/household/presentation/join_household_screen.dart';
import '../../features/household/presentation/providers.dart';
import '../../features/household/presentation/setup_screen.dart';
import '../../features/household/presentation/splash_screen.dart';
import '../../features/members/presentation/members_screen.dart';
import '../../features/members/presentation/providers.dart';
import '../../features/recurring/presentation/recurring_form_screen.dart';
import '../../features/recurring/presentation/recurring_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/presentation/transaction_form_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/vehicles/presentation/fuel_log_form_screen.dart';
import '../../features/vehicles/presentation/maintenance_form_screen.dart';
import '../../features/vehicles/presentation/vehicle_detail_screen.dart';
import '../../features/vehicles/presentation/vehicle_form_screen.dart';
import '../../features/vehicles/presentation/vehicles_screen.dart';
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
  final linkedMemberSubscription =
      ref.listen(linkedMemberProvider, (_, _) => refresh.notify());
  ref.onDispose(() {
    authSubscription.close();
    membershipSubscription.close();
    linkedMemberSubscription.close();
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: splashRoute,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final membership = ref.read(membershipProvider);
      final linked = ref.read(linkedMemberProvider);
      return appRedirect(
        authLoading: auth.isLoading,
        signedIn: auth.value != null,
        membershipLoading: membership.isLoading,
        hasMembership: membership.value != null,
        location: state.matchedLocation,
        memberLoading: linked.isLoading,
        hasLinkedMember: linked.value ?? true,
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

      // Detail routes: declared before the shell so '/transactions/new'
      // and '/transactions/edit/:id' win over the plain branch path.
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/transactions/edit/:id',
        builder: (context, state) => TransactionFormScreen(
          transactionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),

      // Phase 3: vehicles & car (fuel log + maintenance), plus recurring
      // fixed commitments. Specific paths are declared before the
      // '/vehicles/:id' detail route so 'new'/'edit' aren't swallowed.
      GoRoute(
        path: '/vehicles/new',
        builder: (context, state) => const VehicleFormScreen(),
      ),
      GoRoute(
        path: '/vehicles/edit/:id',
        builder: (context, state) => VehicleFormScreen(
          vehicleId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/vehicles/:id/fuel/new',
        builder: (context, state) => FuelLogFormScreen(
          vehicleId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/vehicles/:id/maintenance/new',
        builder: (context, state) => MaintenanceFormScreen(
          vehicleId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/vehicles/:id/maintenance/edit/:itemId',
        builder: (context, state) => MaintenanceFormScreen(
          vehicleId: state.pathParameters['id']!,
          itemId: state.pathParameters['itemId'],
        ),
      ),
      GoRoute(
        path: '/vehicles/:id',
        builder: (context, state) => VehicleDetailScreen(
          vehicleId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/recurring/new',
        builder: (context, state) => const RecurringFormScreen(),
      ),
      GoRoute(
        path: '/recurring/edit/:id',
        builder: (context, state) => RecurringFormScreen(
          ruleId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/recurring',
        builder: (context, state) => const RecurringScreen(),
      ),

      // Legacy logins (household but no linked person) must finish setup
      // here before the router lets them into the shell.
      GoRoute(
        path: claimRoute,
        builder: (context, state) => const ClaimScreen(),
      ),
      GoRoute(
        path: '/household-members',
        builder: (context, state) => const HouseholdMembersScreen(),
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
              path: '/members',
              builder: (context, state) => const MembersScreen(),
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
