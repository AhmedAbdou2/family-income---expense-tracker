import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/export/domain/export_repository.dart';
import 'package:family_income_expense_tracker/features/export/presentation/export_screen.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/pets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/vehicles/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Export screen is a form with a segmented control, four list rows, two
/// buttons and two help lines - the exact shape that overflows on a 360px
/// phone in Arabic. Pumped at 360 / 800 / 1854px for both locales and all
/// three roles it must never throw.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

final _members = <Member>[
  const Member(
    id: 'm1',
    householdId: 'h1',
    name: 'Alexandra',
    isActive: true,
    userId: 'u1',
  ),
  const Member(
    id: 'm2',
    householdId: 'h1',
    // A long Arabic name: the person row must ellipsize, not overflow.
    name: 'عبد الرحمن بن عبد الله الطويل',
    isActive: true,
  ),
];

final _categories = <Category>[
  const Category(
    id: 'food',
    householdId: 'h1',
    group: CategoryGroup.general,
    nameEn: 'Food & groceries',
    nameAr: 'الطعام والبقالة',
    icon: 'restaurant',
    color: '#EF5350',
  ),
];

Widget _app({required MemberRole role, required Locale locale}) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        membersProvider.overrideWith((ref) async => _members),
        categoriesProvider.overrideWith((ref) async => _categories),
        petsProvider.overrideWith((ref) async => const []),
        vehiclesProvider.overrideWith((ref) async => const []),
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
        home: const ExportScreen(),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

const _sizes = <Size>[Size(360, 800), Size(800, 1000), Size(1854, 1000)];

void main() {
  for (final size in _sizes) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final role in MemberRole.values) {
        testWidgets(
          'Export lays out at ${size.width.toInt()}px, '
          '${locale.languageCode}, ${role.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(_app(role: role, locale: locale));
            await _settle(tester);

            expect(tester.takeException(), isNull);
            expect(find.byType(ExportScreen), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('the four filter rows and the CSV action are on screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.owner, locale: const Locale('en')),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.event_outlined), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    expect(find.text('Download CSV (Excel)'), findsOneWidget);
    expect(find.text('Download PDF summary'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets(
      'the PDF action is wired in (sample approved)',
      (tester) async {
    expect(pdfExportEnabled, isTrue);

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.owner, locale: const Locale('en')),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('the CSV action is enabled by default (the month so far)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.adult, locale: const Locale('en')),
    );
    await _settle(tester);

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Download CSV (Excel)'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a window with no rows says so instead of saving an empty file',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettings.new),
          membershipProvider.overrideWith(
            (ref) async => const Membership(
              household: _household,
              role: MemberRole.adult,
            ),
          ),
          membersProvider.overrideWith((ref) async => _members),
          categoriesProvider.overrideWith((ref) async => _categories),
          petsProvider.overrideWith((ref) async => const []),
          vehiclesProvider.overrideWith((ref) async => const []),
          exportRepositoryProvider.overrideWith((ref) => _EmptyExport()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: ExportScreen(),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Download CSV (Excel)'));
    await _settle(tester);

    expect(find.text('No transactions in this period.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// An export source with nothing in the window.
class _EmptyExport implements ExportRepository {
  @override
  Future<List<Transaction>> fetchForExport({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) async =>
      const <Transaction>[];
}
