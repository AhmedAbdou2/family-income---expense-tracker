import '../../transactions/domain/entities.dart';

/// One named amount in a summary table.
class AmountLine {
  const AmountLine({required this.name, required this.amountMinorUnits});

  final String name;
  final int amountMinorUnits;
}

/// This-month totals for the PDF: income, expenses, balance plus the
/// expense breakdown per category and per person.
///
/// Pure: the caller passes the already-resolved display names, so the same
/// totals can be asserted with exact numbers in tests. By construction it
/// covers the same rows the dashboard/category/person figures do.
class MonthSummary {
  const MonthSummary({
    required this.incomeMinorUnits,
    required this.expensesMinorUnits,
    required this.byCategory,
    required this.byPerson,
  });

  final int incomeMinorUnits;
  final int expensesMinorUnits;
  final List<AmountLine> byCategory;
  final List<AmountLine> byPerson;

  int get balanceMinorUnits => incomeMinorUnits - expensesMinorUnits;

  bool get isEmpty =>
      incomeMinorUnits == 0 && expensesMinorUnits == 0;

  static MonthSummary fromTransactions(
    List<Transaction> rows, {
    required Map<String, String> categoryNames,
    required Map<String, String> memberNames,
  }) {
    var income = 0;
    var expenses = 0;
    final categoryTotals = <String, int>{};
    final personTotals = <String, int>{};

    for (final row in rows) {
      if (row.type == TransactionType.income) {
        income += row.amountMinorUnits;
        continue;
      }
      expenses += row.amountMinorUnits;
      categoryTotals.update(
        row.categoryId,
        (value) => value + row.amountMinorUnits,
        ifAbsent: () => row.amountMinorUnits,
      );
      personTotals.update(
        row.memberId,
        (value) => value + row.amountMinorUnits,
        ifAbsent: () => row.amountMinorUnits,
      );
    }

    return MonthSummary(
      incomeMinorUnits: income,
      expensesMinorUnits: expenses,
      byCategory: _lines(categoryTotals, categoryNames),
      byPerson: _lines(personTotals, memberNames),
    );
  }

  static List<AmountLine> _lines(
    Map<String, int> totals,
    Map<String, String> names,
  ) {
    final lines = totals.entries
        .map(
          (entry) => AmountLine(
            name: names[entry.key] ?? '',
            amountMinorUnits: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byAmount = b.amountMinorUnits.compareTo(a.amountMinorUnits);
        return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
      });
    return lines;
  }
}