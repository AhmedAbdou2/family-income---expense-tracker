import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/receipts/domain/entities.dart';
import 'package:family_income_expense_tracker/features/receipts/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/receipts/presentation/receipt_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The receipts block sits inside the transaction form, which is the densest
/// screen in the app. It is pumped at 360 / 800 / 1854px, in both locales and
/// for all three roles: a child must get the read-only shape (no camera
/// button), everyone else the add action.
///
/// The fixture uses PDFs because an image receipt renders through
/// Image.network(signedUrl) - there is no network in a widget test, and that
/// path is covered by the repository/processor tests instead.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

const _transactionId = 't1';

final _receipts = <Receipt>[
  const Receipt(
    id: 'r1',
    transactionId: _transactionId,
    storagePath: 'h1/t1/aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa.pdf',
    mime: 'application/pdf',
    sizeBytes: 1024 * 1024 + 400 * 1024,
  ),
  const Receipt(
    id: 'r2',
    transactionId: _transactionId,
    storagePath: 'h1/t1/bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb.pdf',
    mime: 'application/pdf',
    sizeBytes: 524288,
  ),
  const Receipt(
    id: 'r3',
    transactionId: _transactionId,
    storagePath: 'h1/t1/cccccccc-3333-4333-8333-cccccccccccc.pdf',
    mime: 'application/pdf',
    sizeBytes: 900,
  ),
];

Widget _app({
  required MemberRole role,
  required Locale locale,
  required List<Receipt> receipts,
}) =>
    ProviderScope(
      // A fresh key per pump: two pumpWidget calls at the same position would
      // otherwise reuse the first ProviderContainer (and its already-resolved
      // membership) instead of building the new role's tree.
      key: UniqueKey(),
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        transactionReceiptsProvider(_transactionId)
            .overrideWith((ref) async => receipts),
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
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ReceiptSection(transactionId: _transactionId),
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

const _sizes = <Size>[Size(360, 800), Size(800, 1000), Size(1854, 1000)];

void main() {
  for (final size in _sizes) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final role in MemberRole.values) {
        testWidgets(
          'Receipts lays out at ${size.width.toInt()}px, '
          '${locale.languageCode}, ${role.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _app(role: role, locale: locale, receipts: _receipts),
            );
            await _settle(tester);

            expect(tester.takeException(), isNull);
            expect(find.byType(ReceiptSection), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('the header carries the count out of the cap', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        role: MemberRole.adult,
        locale: const Locale('en'),
        receipts: _receipts,
      ),
    );
    await _settle(tester);

    expect(find.text('Receipts'), findsOneWidget);
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('PDF document'), findsNWidgets(3));
    // receiptSizeLabel: MB with one decimal, KB rounded, bytes below 1 KB raw.
    expect(find.text('1.4 MB'), findsOneWidget);
    expect(find.text('512 KB'), findsOneWidget);
    expect(find.text('900 B'), findsOneWidget);
  });

  for (final role in const [MemberRole.owner, MemberRole.adult]) {
    testWidgets('${role.name} gets the add action', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(role: role, locale: const Locale('en'), receipts: _receipts),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a child gets the read-only shape (no camera button)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        role: MemberRole.child,
        locale: const Locale('en'),
        receipts: _receipts,
      ),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    // The rows are still listed (RLS is what actually hides them server side).
    expect(find.text('PDF document'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no receipts the empty line is shown', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        role: MemberRole.owner,
        locale: const Locale('en'),
        receipts: const [],
      ),
    );
    await _settle(tester);

    expect(find.text('No receipts attached yet.'), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);
  });
}
