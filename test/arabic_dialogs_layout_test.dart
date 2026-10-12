import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/recurring/presentation/recurring_delete.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/transaction_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The delete dialogs hold the longest user-facing text in the app. Pumped in
/// Arabic at a 360px phone width (with the longest variant: a fixed-expense
/// posting that is also fuel-linked) they must lay out without any exception.
Widget _app({required Widget child}) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: child,
    );

Widget _opener(VoidCallback onPressed) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: onPressed, child: const Text('open')),
        ),
      ),
    );

void main() {
  testWidgets('transaction delete dialog fits 360px in Arabic', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        child: _opener(
          () => showTransactionDeleteDialog(
            tester.element(find.byType(Scaffold)),
            categoryName: 'مصروفات السيارة',
            personLabel: 'سارة',
            dateLabel: '12 أكتوبر 2026',
            amountLabel: '- 150.00 ج.م',
            isExpense: true,
            fromFixed: true,
            fuelLinked: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('إيقاف هذا المصروف الثابت مؤقتًا أيضًا'), findsOneWidget);
  });

  testWidgets('recurring delete dialog fits 360px in Arabic', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        child: _opener(
          () => showRecurringDeleteDialog(
            tester.element(find.byType(Scaffold)),
            postedThisMonthCount: 2,
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('تُحذف أيضًا المعاملتان المسجّلتان هذا الشهر'),
      findsOneWidget,
    );
  });
}
