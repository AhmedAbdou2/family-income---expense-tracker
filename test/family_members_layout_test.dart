import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/auth/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/family_members_screen.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/profile_screen.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout sweep: the Family list and the profile header must render the role
/// badge next to a very long name at phone / tablet / desktop widths without
/// any layout exception, in EN and AR (RTL).
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _longName = 'Thessaloniki Rodriguez-Alexandropoulos';
const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');
const _longMember = Member(
  id: 'm1',
  householdId: 'h1',
  name: _longName,
  isActive: true,
  userId: 'u1',
);

Widget _shell({
  required Widget child,
  required MemberRole role,
  required List<Member> members,
  Locale locale = const Locale('en'),
}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        authStateProvider.overrideWith((ref) => Stream.value('u1')),
        membersProvider.overrideWith((ref) async => members),
        householdLoginsProvider.overrideWith(
          (ref) async => [
            HouseholdLogin(
              userId: 'u1',
              role: role,
              joinedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        categoriesProvider.overrideWith((ref) async => const <Category>[]),
        memberMonthTransactionsProvider('m1')
            .overrideWith((ref) async => const <Transaction>[]),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: child,
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

Future<void> _pumpAt(WidgetTester tester, Size size, Widget app) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  const sizes = <String, Size>{
    'phone 360x640': Size(360, 640),
    'tablet 800x800': Size(800, 800),
    'desktop 1854x961': Size(1854, 961),
  };

  for (final role in MemberRole.values) {
    for (final entry in sizes.entries) {
      testWidgets(
        'family list ${role.name} at ${entry.key} with a long name',
        (tester) async {
          await _pumpAt(
            tester,
            entry.value,
            _shell(
              role: role,
              members: const [_longMember],
              child: const FamilyMembersScreen(),
            ),
          );

          expect(_drainExceptions(tester), isEmpty,
              reason: 'unexpected layout exception at ${entry.key}');
          expect(find.text(_longName), findsOneWidget);
        },
      );
    }
  }

  testWidgets('profile header shows the role badge (EN)', (tester) async {
    await _pumpAt(
      tester,
      const Size(360, 640),
      _shell(
        role: MemberRole.owner,
        members: const [_longMember],
        child: const ProfileScreen(memberId: 'm1'),
      ),
    );

    expect(_drainExceptions(tester), isEmpty);
    expect(find.text(_longName), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('profile header shows the role badge (AR, RTL)', (tester) async {
    await _pumpAt(
      tester,
      const Size(360, 640),
      _shell(
        role: MemberRole.adult,
        members: const [_longMember],
        locale: const Locale('ar'),
        child: const ProfileScreen(memberId: 'm1'),
      ),
    );

    final label = find.text('بالغ');
    expect(_drainExceptions(tester), isEmpty);
    expect(label, findsOneWidget);
    expect(Directionality.of(tester.element(label)), TextDirection.rtl);
  });

  testWidgets('profile header at desktop width with a long name',
      (tester) async {
    await _pumpAt(
      tester,
      const Size(1854, 961),
      _shell(
        role: MemberRole.owner,
        members: const [_longMember],
        child: const ProfileScreen(memberId: 'm1'),
      ),
    );

    expect(_drainExceptions(tester), isEmpty);
    expect(find.text(_longName), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });
}
