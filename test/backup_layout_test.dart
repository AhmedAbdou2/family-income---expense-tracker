import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_repository.dart';
import 'package:family_income_expense_tracker/features/backup/domain/backup_tables.dart';
import 'package:family_income_expense_tracker/features/backup/presentation/backup_screen.dart';
import 'package:family_income_expense_tracker/features/backup/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The owner-only Backup screen is a stack of paragraphs, a warning banner, an
/// estimate line and two buttons - the shape that overflows on a 360px phone in
/// Arabic. Pumped at 360 / 800 / 1854px for both locales and all three roles it
/// must never throw.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

class _FakeBackupRepository implements BackupRepository {
  _FakeBackupRepository({this.receiptRows = const []});

  final List<Map<String, dynamic>> receiptRows;

  @override
  Future<List<Map<String, dynamic>>> fetchPage({
    required BackupTable table,
    required String householdId,
    required int offset,
    required int limit,
  }) async {
    if (table.name == 'transaction_receipts') return receiptRows;
    return const [];
  }

  @override
  Future<List<int>> downloadReceipt(String storagePath) async => const [1];
}

Widget _app({
  required MemberRole role,
  required Locale locale,
  List<Map<String, dynamic>> receiptRows = const [],
}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        backupRepositoryProvider.overrideWith(
          (ref) => _FakeBackupRepository(receiptRows: receiptRows),
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
        home: const BackupScreen(),
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
          'Backup lays out at ${size.width.toInt()}px, '
          '${locale.languageCode}, ${role.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _app(role: role, locale: locale),
            );
            await _settle(tester);

            expect(tester.takeException(), isNull);
            expect(find.byType(BackupScreen), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('the warning, both actions and the estimate are on screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(role: MemberRole.owner, locale: const Locale('en')),
    );
    await _settle(tester);

    expect(find.text('Not encrypted'), findsOneWidget);
    expect(find.text('Download full backup (.zip)'), findsOneWidget);
    expect(
      find.text('Download data only (no receipt files)'),
      findsOneWidget,
    );
    expect(find.textContaining('No receipt files'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('above the hard cap the full button is disabled and refused',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        role: MemberRole.owner,
        locale: const Locale('en'),
        receiptRows: [
          {
            'id': 'r1',
            'storage_path': 'h1/t1/big.pdf',
            'size_bytes': backupMaxReceiptBytes + 1,
          },
        ],
      ),
    );
    await _settle(tester);

    final fullButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Download full backup (.zip)'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(fullButton.onPressed, isNull, reason: 'refused above the cap');

    // The data-only escape hatch stays available.
    final dataOnly = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Download data only (no receipt files)'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(dataOnly.onPressed, isNotNull);
    expect(find.textContaining('above the single-file limit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
