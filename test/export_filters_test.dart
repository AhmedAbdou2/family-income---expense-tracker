import 'package:family_income_expense_tracker/features/export/domain/export_filter.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// The export filter is the single predicate behind BOTH the CSV and the PDF,
/// so its boundaries are pinned: inclusive dates, reversed windows that export
/// nothing, and the optional type / person / category narrowing.
Transaction _tx({
  required String id,
  required String type,
  required int amountMinorUnits,
  required String categoryId,
  required String memberId,
  required DateTime date,
}) =>
    Transaction(
      id: id,
      householdId: 'h1',
      type: TransactionType.fromDb(type),
      amountMinorUnits: amountMinorUnits,
      categoryId: categoryId,
      memberId: memberId,
      date: date,
    );

final _rows = <Transaction>[
  _tx(
    id: 'before',
    type: 'expense',
    amountMinorUnits: 100,
    categoryId: 'food',
    memberId: 'm1',
    date: DateTime(2026, 5, 31),
  ),
  _tx(
    id: 'first-day',
    type: 'expense',
    amountMinorUnits: 200,
    categoryId: 'food',
    memberId: 'm1',
    date: DateTime(2026, 6, 1),
  ),
  _tx(
    id: 'middle-income',
    type: 'income',
    amountMinorUnits: 300,
    categoryId: 'salary',
    memberId: 'm2',
    date: DateTime(2026, 6, 15),
  ),
  _tx(
    id: 'last-day',
    type: 'expense',
    amountMinorUnits: 400,
    categoryId: 'transport',
    memberId: 'm2',
    date: DateTime(2026, 6, 30),
  ),
  _tx(
    id: 'after',
    type: 'expense',
    amountMinorUnits: 500,
    categoryId: 'food',
    memberId: 'm1',
    date: DateTime(2026, 7, 1),
  ),
];

void main() {
  test('thisMonth covers the whole calendar month', () {
    final filter = ExportFilter.thisMonth(today: DateTime(2026, 6, 17));
    expect(filter.from, DateTime(2026, 6, 1));
    expect(filter.to, DateTime(2026, 6, 30));
    expect(filter.type, ExportTypeFilter.all);
    expect(filter.isValid, isTrue);
  });

  test('thisMonth handles February in a leap and a common year', () {
    expect(
      ExportFilter.thisMonth(today: DateTime(2026, 2, 3)).to,
      DateTime(2026, 2, 28),
    );
    expect(
      ExportFilter.thisMonth(today: DateTime(2028, 2, 3)).to,
      DateTime(2028, 2, 29),
    );
  });

  test('both ends of the range are inclusive and nothing outside slips in',
      () {
    final filter = ExportFilter(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
    );
    final ids = filter.apply(_rows).map((row) => row.id).toList();

    expect(ids, ['last-day', 'middle-income', 'first-day']);
    expect(ids, isNot(contains('before')));
    expect(ids, isNot(contains('after')));
  });

  test('a time-of-day stamp still counts as that day', () {
    final filter = ExportFilter(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 1),
    );
    final withTime = _tx(
      id: 'with-time',
      type: 'expense',
      amountMinorUnits: 100,
      categoryId: 'food',
      memberId: 'm1',
      date: DateTime(2026, 6, 1, 23, 59),
    );
    expect(filter.includes(withTime), isTrue);
  });

  test('a reversed window exports nothing', () {
    final filter = ExportFilter(
      from: DateTime(2026, 6, 30),
      to: DateTime(2026, 6, 1),
    );
    expect(filter.isValid, isFalse);
    expect(filter.apply(_rows), isEmpty);
  });

  test('the type filter keeps only the requested side', () {
    final expenses = ExportFilter(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      type: ExportTypeFilter.expenses,
    );
    expect(
      expenses.apply(_rows).map((row) => row.id),
      ['last-day', 'first-day'],
    );

    final income = expenses.copyWith(type: ExportTypeFilter.income);
    expect(income.apply(_rows).map((row) => row.id), ['middle-income']);
  });

  test('person and category narrow the same window', () {
    final base = ExportFilter(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
    );
    final byPerson = base.copyWith(memberId: 'm2');
    expect(byPerson.apply(_rows).map((row) => row.id), ['last-day',
      'middle-income']);

    final byCategory = base.copyWith(memberId: 'm2', categoryId: 'transport');
    expect(byCategory.apply(_rows).map((row) => row.id), ['last-day']);
  });

  test('clear flags drop a filter again', () {
    final filter = ExportFilter(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      memberId: 'm2',
      categoryId: 'transport',
    );
    expect(filter.copyWith(clearMember: true).memberId, isNull);
    expect(filter.copyWith(clearCategory: true).categoryId, isNull);
    // copyWith without flags keeps them.
    expect(filter.copyWith().memberId, 'm2');
  });

  test('rows come back newest first', () {
    final filter = ExportFilter(
      from: DateTime(2026, 5, 1),
      to: DateTime(2026, 7, 31),
    );
    final dates = filter.apply(_rows).map((row) => row.date).toList();
    expect(dates, [
      DateTime(2026, 7, 1),
      DateTime(2026, 6, 30),
      DateTime(2026, 6, 15),
      DateTime(2026, 6, 1),
      DateTime(2026, 5, 31),
    ]);
  });
}
