import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/router/redirect.dart';
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

/// `/backup` is OWNER-only (narrower than the adult features). This pins both
/// halves: the pure redirect for every role, and the Settings card pushing the
/// route for the owner only.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

String? _redirect({
  required String location,
  required bool isAdult,
  required bool isOwner,
}) =>
    appRedirect(
      authLoading: false,
      signedIn: true,
      membershipLoading: false,
      hasMembership: true,
      location: location,
      isAdult: isAdult,
      isOwner: isOwner,
    );

void main() {
  group('the /backup guard', () {
    test('the owner may open /backup (and its sub-paths)', () {
      for (final location in ['/backup', '/backup/anything']) {
        expect(
          _redirect(location: location, isAdult: true, isOwner: true),
          isNull,
          reason: location,
        );
      }
    });

    test('an adult who is not the owner is sent to the dashboard', () {
      expect(
        _redirect(location: '/backup', isAdult: true, isOwner: false),
        '/',
      );
    });

    test('a child is sent to the dashboard', () {
      expect(
        _redirect(location: '/backup', isAdult: false, isOwner: false),
        '/',
      );
    });

    test('a non-owner adult still reaches the normal routes', () {
      expect(
        _redirect(location: '/transactions', isAdult: true, isOwner: false),
        isNull,
      );
    });
  });

  testWidgets('the owner sees the Backup card and it pushes /backup',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/backup', builder: (_, _) => const _BackupStub()),
      ],
    );

    await _pump(tester, router, MemberRole.owner);
    await _settle(tester);

    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Full backup'), findsOneWidget);

    await tester.tap(find.text('Full backup'));
    await _settle(tester);

    expect(find.byType(_BackupStub), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an adult who is not the owner never sees the Backup card',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/backup', builder: (_, _) => const _BackupStub()),
      ],
    );

    await _pump(tester, router, MemberRole.adult);
    await _settle(tester);

    // The Data section is still there (export/sweep), only Backup is gone.
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Full backup'), findsNothing);
  });

  testWidgets('a child never sees the Backup card', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/backup', builder: (_, _) => const _BackupStub()),
      ],
    );

    await _pump(tester, router, MemberRole.child);
    await _settle(tester);

    expect(find.text('Full backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _BackupStub extends StatelessWidget {
  const _BackupStub();

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
