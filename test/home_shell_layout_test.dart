import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/auth/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/home_shell.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The account tile inside the [NavigationRail] `leading` used to hold a
/// [Row] with an [Expanded] child. A `Row` (non-flex child of a `Row`) is
/// laid out with unbounded width, and a flex child in an unbounded main
/// axis throws. This screen-level sweep pumps the real shell at phone,
/// tablet and desktop widths for every role so any layout exception fails
/// the test.
const _longName = 'Thessaloniki Rodriguez-Alexandropoulos';

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
        authStateProvider.overrideWith((ref) => Stream.value('u1')),
        membersProvider.overrideWith(
          (ref) async => const [
            Member(
              id: 'm1',
              householdId: 'h1',
              name: _longName,
              isActive: true,
              userId: 'u1',
            ),
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
    );

List<Object> _drainExceptions(WidgetTester tester) {
  final errors = <Object>[];
  while (true) {
    final exception = tester.takeException();
    if (exception == null) break;
    errors.add(exception);
  }
  return errors;
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  MemberRole role,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = _buildRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(_app(router, role));
  await _pumpFrames(tester);
}

void main() {
  const sizes = <String, Size>{
    'phone 360x640': Size(360, 640),
    'tablet 800x800': Size(800, 800),
    'rail 900x800': Size(900, 800),
    'desktop 1854x961': Size(1854, 961),
  };

  for (final role in MemberRole.values) {
    for (final entry in sizes.entries) {
      testWidgets('${role.name} shell lays out at ${entry.key} with a long name',
          (tester) async {
        await _pumpAt(tester, entry.value, role);

        expect(_drainExceptions(tester), isEmpty,
            reason: 'unexpected layout exception at ${entry.key}');
        expect(find.byType(HomeShell), findsOneWidget);

        final wide = entry.value.width >= 840;
        expect(find.byType(NavigationRail), wide ? findsOneWidget : findsNothing);
        expect(
          find.byType(NavigationBar),
          wide ? findsNothing : findsOneWidget,
        );
      });
    }
  }

  testWidgets('extended rail shows the account name and does not throw',
      (tester) async {
    await _pumpAt(tester, const Size(1854, 961), MemberRole.owner);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text(_longName), findsOneWidget);
    expect(_drainExceptions(tester), isEmpty);
  });

  testWidgets('collapsed rail shows the avatar, not the name',
      (tester) async {
    await _pumpAt(tester, const Size(900, 800), MemberRole.owner);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.text(_longName), findsNothing);
    expect(_drainExceptions(tester), isEmpty);
  });

  testWidgets('drawer opens at phone width for an adult without throwing',
      (tester) async {
    await _pumpAt(tester, const Size(360, 640), MemberRole.adult);

    await tester.tap(find.byIcon(Icons.menu_rounded).first);
    await _pumpFrames(tester);

    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('Pets'), findsOneWidget);
    expect(_drainExceptions(tester), isEmpty);
  });

  testWidgets('bottom bar uses short fixed label at 360px width',
      (tester) async {
    await _pumpAt(tester, const Size(360, 640), MemberRole.adult);
    expect(_drainExceptions(tester), isEmpty);
    expect(find.text('Fixed'), findsOneWidget);
  });

}
