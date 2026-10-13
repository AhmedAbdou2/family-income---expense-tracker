import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/pets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/pets/presentation/pet_detail_screen.dart';
import 'package:family_income_expense_tracker/features/pets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reminders block lives on the pet detail screen: status chips, a due
/// date, a "next" date and a long Arabic vaccine name on a 360px phone. Also
/// pumped for a child, whose RLS returns nothing, to prove the empty shape is
/// safe (the router normally keeps children off this route).
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

final _pet = const Pet(
  id: 'p1',
  householdId: 'h1',
  name: 'لونا',
  type: PetType.cat,
  isActive: true,
);

final _categories = <Category>[
  const Category(
    id: 'pet_food',
    householdId: 'h1',
    group: CategoryGroup.pet,
    nameEn: 'Pet food',
    nameAr: 'طعام الحيوانات الأليفة',
    icon: 'pets',
    color: '#8D6E63',
  ),
];

final _members = <Member>[
  const Member(
    id: 'm1',
    householdId: 'h1',
    name: 'أحمد',
    isActive: true,
    userId: 'u1',
  ),
];

final _reminders = <PetReminder>[
  PetReminder(
    id: 'rm1',
    householdId: 'h1',
    petId: 'p1',
    title: 'تطعيم السعار السنوي',
    kind: PetReminderKind.vaccine,
    // Overdue.
    dueDate: DateTime.now().subtract(const Duration(days: 30)),
    repeatMonths: 12,
  ),
  PetReminder(
    id: 'rm2',
    householdId: 'h1',
    petId: 'p1',
    title: 'زيارة الطبيب البيطري لفحص الأسنان والتنظيف',
    kind: PetReminderKind.vet,
    // Due soon (inside the 14-day window).
    dueDate: DateTime.now().add(const Duration(days: 3)),
  ),
  PetReminder(
    id: 'rm3',
    householdId: 'h1',
    petId: 'p1',
    title: 'مكمل غذائي شهري',
    kind: PetReminderKind.other,
    dueDate: DateTime.now().add(const Duration(days: 90)),
    repeatMonths: 1,
  ),
  PetReminder(
    id: 'rm4',
    householdId: 'h1',
    petId: 'p1',
    title: 'تم',
    kind: PetReminderKind.other,
    dueDate: DateTime.now().subtract(const Duration(days: 400)),
    doneAt: DateTime.now().subtract(const Duration(days: 399)),
  ),
];

Widget _app({required MemberRole role, required Locale locale}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        categoriesProvider.overrideWith((ref) async => _categories),
        membersProvider.overrideWith((ref) async => _members),
        petsProvider.overrideWith(
          (ref) async => role == MemberRole.child ? const <Pet>[] : [_pet],
        ),
        petMonthTransactionsProvider(_pet.id).overrideWith(
          (ref) async => role == MemberRole.child
              ? const <Transaction>[]
              : [
                  Transaction(
                    id: 't1',
                    householdId: 'h1',
                    type: TransactionType.expense,
                    amountMinorUnits: 45000,
                    categoryId: 'pet_food',
                    memberId: 'm1',
                    petId: _pet.id,
                    date: DateTime.now(),
                  ),
                ],
        ),
        petRemindersProvider(_pet.id).overrideWith(
          (ref) async =>
              role == MemberRole.child ? const <PetReminder>[] : _reminders,
        ),
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
        home: PetDetailScreen(petId: _pet.id),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

const _sizes = <Size>[Size(360, 800), Size(800, 1000), Size(1854, 1000)];

void main() {
  for (final size in _sizes) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets(
        'Pet reminders lay out at ${size.width.toInt()}px, '
        '${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _app(role: MemberRole.owner, locale: locale),
          );
          await _settle(tester);

          expect(tester.takeException(), isNull);
          expect(find.byType(PetDetailScreen), findsOneWidget);
          expect(find.text('مكمل غذائي شهري'), findsOneWidget);
        },
      );

      testWidgets(
        'A child sees the empty reminder shape at ${size.width.toInt()}px, '
        '${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _app(role: MemberRole.child, locale: locale),
          );
          await _settle(tester);

          expect(tester.takeException(), isNull);
          expect(find.text('مكمل غذائي شهري'), findsNothing);
        },
      );
    }
  }

  testWidgets('overdue, due-soon and scheduled are listed in that order',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.owner, locale: const Locale('ar')),
    );
    await _settle(tester);

    final overdue = tester.getTopLeft(find.text('متأخر')).dy;
    final dueSoon = tester.getTopLeft(find.text('يستحق قريبًا')).dy;
    final scheduled = tester.getTopLeft(find.text('مجدول')).dy;

    expect(overdue, lessThan(dueSoon));
    expect(dueSoon, lessThan(scheduled));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a completed reminder keeps its row, struck through, last',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.owner, locale: const Locale('ar')),
    );
    await _settle(tester);

    // The done state is carried by the strikethrough + the "completed on"
    // line, never by a colour or a text chip alone.
    final doneTitle = tester.widget<Text>(find.text('تم'));
    expect(doneTitle.style?.decoration, TextDecoration.lineThrough);

    final scheduled = tester.getTopLeft(find.text('مجدول')).dy;
    expect(tester.getTopLeft(find.text('تم')).dy, greaterThan(scheduled));

    // Its tick-off action is gone (it cannot be completed twice).
    expect(
      find.byTooltip('تسجيل الإنجاز'),
      findsNWidgets(3),
      reason: 'only the three open reminders can be completed',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the add-reminder action is offered and the section titled',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.adult, locale: const Locale('en')),
    );
    await _settle(tester);

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.byIcon(Icons.add_alarm_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
