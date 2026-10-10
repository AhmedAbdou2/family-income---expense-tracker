import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/home_shell.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Vehicles and Pets are adult-only destinations reachable from the drawer,
/// never from the short bottom bar. A child sees neither.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

StatefulShellBranch _branch(String path, String label) =>
    StatefulShellBranch(routes: [
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(
          appBar: AppBar(leading: const ShellMenuButton()),
          body: Center(child: Text(label)),
        ),
      ),
    ]);

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => HomeShell(shell: shell),
          branches: [
            _branch('/', 'dashboard-branch'),
            _branch('/transactions', 'transactions-branch'),
            _branch('/members', 'members-branch'),
            _branch('/recurring', 'recurring-branch'),
            _branch('/settings', 'settings-branch'),
            _branch('/vehicles', 'vehicles-branch'),
            _branch('/pets', 'pets-branch'),
          ],
        ),
      ],
    );

Widget _app(GoRouter router, MemberRole role) => ProviderScope(
      overrides: [
        membershipProvider.overrideWith(
          (ref) async => Membership(
            household: const Household(id: 'h1', name: 'Home', currency: 'EGP'),
            role: role,
          ),
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
    );

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_rounded).first);
  await _pumpFrames(tester);
}

void main() {
  testWidgets('owner opens Vehicles from the drawer', (tester) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, MemberRole.owner));
    await _pumpFrames(tester);

    expect(find.text('Vehicles'), findsNothing);
    await _openDrawer(tester);
    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('Pets'), findsOneWidget);
    await tester.tap(find.text('Vehicles'));
    await _pumpFrames(tester);
    expect(find.text('vehicles-branch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adult opens Vehicles from the drawer', (tester) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, MemberRole.adult));
    await _pumpFrames(tester);
    await _openDrawer(tester);
    expect(find.text('Vehicles'), findsOneWidget);
  });

  testWidgets('child does NOT see Vehicles or Pets', (tester) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, MemberRole.child));
    await _pumpFrames(tester);

    await _openDrawer(tester);
    expect(find.text('Vehicles'), findsNothing);
    expect(find.text('Pets'), findsNothing);
    expect(find.text('Fixed'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
