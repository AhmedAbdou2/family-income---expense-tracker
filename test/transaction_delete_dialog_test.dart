import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/transaction_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TransactionDeleteResult?> _show(
  GlobalKey<NavigatorState> navKey, {
  bool fromFixed = false,
  bool fuelLinked = false,
}) {
  return showTransactionDeleteDialog(
    navKey.currentContext!,
    categoryName: 'Groceries',
    personLabel: 'Alex',
    dateLabel: 'Oct 10, 2026',
    amountLabel: '- 150.00 EGP',
    isExpense: true,
    fromFixed: fromFixed,
    fuelLinked: fuelLinked,
  );
}

Widget _app(GlobalKey<NavigatorState> navKey, Widget child) => MaterialApp(
      navigatorKey: navKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  testWidgets('delete dialog shows the transaction details and a compact '
      'destructive Delete action', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    TransactionDeleteResult? result;

    await tester.pumpWidget(
      _app(
        navKey,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => result = await _show(navKey),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Oct 10, 2026'), findsOneWidget);
    expect(find.text('- 150.00 EGP'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result?.confirmed, isTrue);
    expect(result?.pauseRule, isFalse);
  });

  testWidgets('fixed + fuel-linked delete shows the notes and the optional '
      'pause checkbox', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    TransactionDeleteResult? result;

    await tester.pumpWidget(
      _app(
        navKey,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => result = await _show(
                navKey,
                fromFixed: true,
                fuelLinked: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('The linked fuel log will also be deleted.'),
      findsOneWidget,
    );
    expect(find.text('Also pause this fixed expense'), findsOneWidget);

    // Default is off; ticking it sets pauseRule on confirm.
    expect(result, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result?.confirmed, isTrue);
    expect(result?.pauseRule, isTrue);
  });
}
