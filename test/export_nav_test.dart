import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/pets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/settings/presentation/settings_screen.dart';
import 'package:family_income_expense_tracker/features/vehicles/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// `/export` is an adult-only route reached from two places (the Settings
/// "Data" card and the Reports app bar). This pins both halves: the pure
/// redirect for every role, and the tile really pushing the route.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

void main() {
  testWidgets('the Settings Data card pushes /export', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/export', builder: (_, _) => const _ExportStub()),
      ],
    );

    await _pump(tester, router, MemberRole.owner);
    await _settle(tester);

    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await _settle(tester);

    expect(find.byType(_ExportStub), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a child never sees the Data section', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/export', builder: (_, _) => const _ExportStub()),
      ],
    );

    await _pump(tester, router, MemberRole.child);
    await _settle(tester);

    expect(find.text('Data'), findsNothing);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Export & backups'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ExportStub extends StatelessWidget {
  const _ExportStub();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('stub'));
}

Future<void> _pump(
  WidgetTester tester,
  GoRouter router,
  MemberRole role,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        invitesProvider.overrideWith((ref) async => const []),
        householdLoginsProvider.overrideWith((ref) async => const []),
        membersProvider.overrideWith((ref) async => const []),
        categoriesProvider.overrideWith((ref) async => const []),
        vehiclesProvider.overrideWith((ref) async => const []),
        petsProvider.overrideWith((ref) async => const []),
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
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}
