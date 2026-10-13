import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/pets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/pets/presentation/pet_detail_screen.dart';
import 'package:family_income_expense_tracker/features/pets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The reminder routes hang off the pet detail screen. The redirect half
/// (adults only, children bounced) lives in test/redirect_test.dart; this
/// pins the actual pushes: the add action opens the form and a reminder row
/// opens that reminder's editor.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

final _pet = const Pet(
  id: 'p1',
  householdId: 'h1',
  name: 'Luna',
  type: PetType.cat,
  isActive: true,
);

final _reminders = <PetReminder>[
  PetReminder(
    id: 'rm1',
    householdId: 'h1',
    petId: 'p1',
    title: 'Rabies booster',
    kind: PetReminderKind.vaccine,
    dueDate: DateTime.now().add(const Duration(days: 3)),
    repeatMonths: 12,
  ),
];

void main() {
  testWidgets('the add action opens the reminder form', (tester) async {
    final router = _router();
    await _pump(tester, router);
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.add_alarm_outlined));
    await _settle(tester);

    expect(find.text('new-reminder-stub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a reminder opens its editor', (tester) async {
    final router = _router();
    await _pump(tester, router);
    await _settle(tester);

    await tester.tap(find.text('Rabies booster'));
    await _settle(tester);

    expect(find.text('edit-reminder-stub:rm1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router() => GoRouter(
      initialLocation: '/pets/p1',
      routes: [
        GoRoute(
          path: '/pets/:id',
          builder: (_, state) =>
              PetDetailScreen(petId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'reminders/new',
              builder: (_, _) => const Scaffold(
                body: Text('new-reminder-stub'),
              ),
            ),
            GoRoute(
              path: 'reminders/edit/:reminderId',
              builder: (_, state) => Scaffold(
                body: Text(
                  'edit-reminder-stub:'
                  '${state.pathParameters['reminderId']}',
                ),
              ),
            ),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => const Membership(
            household: _household,
            role: MemberRole.owner,
          ),
        ),
        categoriesProvider.overrideWith((ref) async => const []),
        membersProvider.overrideWith((ref) async => const []),
        petsProvider.overrideWith((ref) async => [_pet]),
        petMonthTransactionsProvider(_pet.id)
            .overrideWith((ref) async => const []),
        petRemindersProvider(_pet.id).overrideWith((ref) async => _reminders),
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
