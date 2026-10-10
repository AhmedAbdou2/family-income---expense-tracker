import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/auth/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/family_members_screen.dart';
import 'package:family_income_expense_tracker/features/household/presentation/home_shell.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pumps frames for at most [frames] * [step] - never pumpAndSettle, so a
/// stuck transition can't hang the test.
Future<void> pumpFrames(
  WidgetTester tester, {
  int frames = 15,
  Duration step = const Duration(milliseconds: 80),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Mirrors the app's route shape: the shell (quick-add FAB) with a People
/// branch that has its own add control, plus a top-level detail route that
/// gets pushed on top. Hero collection on that push walks the WHOLE shell
/// subtree - including IndexedStack branches that are offstage.
GoRouter buildTestRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: Text('detail')),
            body: const SizedBox.shrink(),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => HomeShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('dashboard'))),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('transactions'))),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/members',
                builder: (context, state) => const FamilyMembersScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('settings'))),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/vehicles',
                builder: (context, state) =>
                    const Scaffold(body: Center(child: Text('vehicles'))),
              ),
            ]),
          ],
        ),
      ],
    );

void main() {
  testWidgets(
    'route transitions never hit duplicate hero tags with FABs present',
    (tester) async {
      final router = buildTestRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream<String?>.value('user-1'),
            ),
            membershipProvider.overrideWith(
              (ref) async => const Membership(
                household: Household(id: 'h1', name: 'Alpha', currency: 'EUR'),
                role: MemberRole.owner,
              ),
            ),
            membersProvider.overrideWith(
              (ref) async => const [
                Member(id: 'm1', householdId: 'h1', name: 'Mom', isActive: true),
              ],
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await pumpFrames(tester);

      // People tab: the shell quick-add FAB and the add-member control
      // coexist in the same Navigator subtree.
      await tester.tap(find.byType(NavigationDestination).at(2));
      await pumpFrames(tester);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);

      // Push: hero collection walks the shell subtree -> this is where
      // 'multiple heroes that share the same tag' used to throw.
      router.push('/detail');
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);

      // Back to the shell: the pop transition collects heroes again.
      router.go('/');
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);

      // Push again from a different tab (People stays mounted offstage).
      router.push('/detail');
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);

      // Pop back and let the transition finish.
      router.pop();
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);

      // Exactly one FAB in the whole shell subtree: the quick-add one.
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
