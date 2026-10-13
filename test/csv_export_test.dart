import 'dart:convert';

import 'package:family_income_expense_tracker/features/export/domain/csv_export.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// The CSV writer is the one place where money leaves the app as text, so its
/// bytes are pinned exactly: UTF-8 BOM, RFC 4180 quoting, CRLF endings and the
/// spreadsheet-injection guard (AMENDMENT E - `= + - @ \t \r`).
Transaction _tx({
  required String id,
  required String type,
  required int amountMinorUnits,
  required String categoryId,
  required String memberId,
  DateTime? date,
  String? note,
  String? vehicleId,
  String? petId,
}) =>
    Transaction(
      id: id,
      householdId: 'h1',
      type: TransactionType.fromDb(type),
      amountMinorUnits: amountMinorUnits,
      categoryId: categoryId,
      memberId: memberId,
      date: date ?? DateTime(2026, 6, 5),
      note: note,
      vehicleId: vehicleId,
      petId: petId,
    );

void main() {
  group('csvCell', () {
    test('leaves ordinary text alone', () {
      expect(csvCell('Food & groceries'), 'Food & groceries');
      expect(csvCell('الطعام والبقالة'), 'الطعام والبقالة');
      expect(csvCell(''), '');
    });

    test('neutralizes every spreadsheet formula trigger', () {
      // The six characters that make Excel/Sheets treat a cell as a formula.
      expect(csvCell('=1+1'), "'=1+1");
      expect(csvCell('+1'), "'+1");
      expect(csvCell('-1'), "'-1");
      expect(csvCell('@SUM(A1)'), "'@SUM(A1)");
      expect(csvCell('\tcmd'), "'\tcmd");
      // A carriage return is both a formula trigger AND an RFC 4180 special,
      // so it gets the guard and the quotes.
      expect(csvCell('\rcmd'), '"\'${'\r'}cmd"');
      // A leading apostrophe is already safe and stays untouched.
      expect(csvCell("'=1+1"), "'=1+1");
    });

    test('only guards the START of a cell', () {
      expect(csvCell('paid 5-10'), 'paid 5-10');
      expect(csvCell('a\tb'), 'a\tb');
    });

    test('quotes RFC 4180 specials and doubles embedded quotes', () {
      expect(csvCell('a,b'), '"a,b"');
      expect(csvCell('a"b'), '"a""b"');
      expect(csvCell('a\nb'), '"a\nb"');
      expect(csvCell('a\r\nb'), '"a\r\nb"');
    });

    test('a guarded cell that also needs quoting gets both', () {
      expect(csvCell('=1,2'), '"\'=1,2"');
    });
  });

  test('the document starts with a UTF-8 BOM', () {
    final bytes = utf8.encode(buildCsv(const [
      ['date'],
    ]));
    expect(bytes.sublist(0, 3), const [0xEF, 0xBB, 0xBF]);
  });

  test('header + one row is byte-exact', () {
    final document = buildCsv([
      const ['date', 'type', 'category', 'person', 'amount', 'currency'],
      const [
        '2026-06-05',
        'expense',
        'Food & groceries',
        'Alexandra',
        '12345.67',
        'EGP',
      ],
    ]);

    expect(
      document,
      '\uFEFF'
      'date,type,category,person,amount,currency\r\n'
      '2026-06-05,expense,Food & groceries,Alexandra,12345.67,EGP\r\n',
    );
  });

  test('a note with a formula is exported as text', () {
    final document = buildCsv([
      csvHeader,
      [
        '2026-06-05',
        'expense',
        'Food',
        'Sam',
        '1.00',
        'EGP',
        '',
        '',
        '=HYPERLINK("http://x")',
      ],
    ]);
    expect(document.contains("'=HYPERLINK(\"\"http://x\"\")"), isTrue);
    expect(document.endsWith('\r\n'), isTrue);
  });

  test('csvRowsFor resolves the household names and keeps the amount exact',
      () {
    final rows = csvRowsFor(
      transactions: [
        _tx(
          id: 't1',
          type: 'expense',
          amountMinorUnits: 1234567,
          categoryId: 'food',
          memberId: 'm1',
          note: 'bread, milk',
          petId: 'p1',
        ),
        _tx(
          id: 't2',
          type: 'income',
          amountMinorUnits: 500000000,
          categoryId: 'salary',
          memberId: 'm2',
          date: DateTime(2026, 6, 1),
          vehicleId: 'v1',
        ),
      ],
      categoryNames: const {'food': 'Food & groceries', 'salary': 'Salary'},
      memberNames: const {'m1': 'Alexandra', 'm2': 'Sam'},
      currency: 'EGP',
      vehicleNames: const {'v1': 'Corolla'},
      petNames: const {'p1': 'Luna'},
    );

    expect(rows.first, csvHeader);
    // No float ever touches an amount: 1234567 minor units -> '12345.67'.
    expect(rows[1], [
      '2026-06-05',
      'expense',
      'Food & groceries',
      'Alexandra',
      '12345.67',
      'EGP',
      '',
      'Luna',
      'bread, milk',
    ]);
    expect(rows[2], [
      '2026-06-01',
      'income',
      'Salary',
      'Sam',
      '5000000.00',
      'EGP',
      'Corolla',
      '',
      '',
    ]);
  });

  test('csvRowsFor renders an unknown id as an empty cell', () {
    final rows = csvRowsFor(
      transactions: [
        _tx(
          id: 't1',
          type: 'expense',
          amountMinorUnits: 100,
          categoryId: 'gone',
          memberId: 'gone',
        ),
      ],
      categoryNames: const {},
      memberNames: const {},
      currency: 'EGP',
    );
    expect(rows[1][2], '');
    expect(rows[1][3], '');
    expect(rows[1][4], '1.00');
  });

  test('a null vehicle/pet id leaves both link cells empty', () {
    final rows = csvRowsFor(
      transactions: [
        _tx(
          id: 't1',
          type: 'expense',
          amountMinorUnits: 100,
          categoryId: 'food',
          memberId: 'm1',
        ),
      ],
      categoryNames: const {'food': 'Food'},
      memberNames: const {'m1': 'Sam'},
      currency: 'EGP',
      vehicleNames: const {'v1': 'Corolla'},
      petNames: const {'p1': 'Luna'},
    );
    expect(rows[1][6], '');
    expect(rows[1][7], '');
  });
}
