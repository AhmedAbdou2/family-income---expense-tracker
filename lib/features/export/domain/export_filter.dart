import '../../transactions/domain/entities.dart';

/// Which transactions an export covers.
enum ExportTypeFilter {
  all('all'),
  expenses('expense'),
  income('income');

  const ExportTypeFilter(this.dbValue);

  final String dbValue;

  bool matches(Transaction transaction) =>
      this == ExportTypeFilter.all || transaction.type.dbValue == dbValue;
}

/// A date window (inclusive) plus an optional type / person / category
/// filter. Pure - the screenshot of a filter is unit-testable without a
/// widget.
class ExportFilter {
  const ExportFilter({
    required this.from,
    required this.to,
    this.type = ExportTypeFilter.all,
    this.memberId,
    this.categoryId,
  });

  /// The window that opens first: the current calendar month.
  factory ExportFilter.thisMonth({DateTime? today}) {
    final now = today ?? DateTime.now();
    return ExportFilter(
      from: DateTime(now.year, now.month),
      to: DateTime(now.year, now.month + 1, 0),
    );
  }

  final DateTime from;
  final DateTime to;
  final ExportTypeFilter type;
  final String? memberId;
  final String? categoryId;

  /// A reversed window exports nothing; the UI refuses it up front.
  bool get isValid => !from.isAfter(to);

  ExportFilter copyWith({
    DateTime? from,
    DateTime? to,
    ExportTypeFilter? type,
    String? memberId,
    String? categoryId,
    bool clearMember = false,
    bool clearCategory = false,
  }) {
    return ExportFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      type: type ?? this.type,
      memberId: clearMember ? null : (memberId ?? this.memberId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  /// One predicate used by BOTH the CSV and the PDF path, so the two can
  /// never disagree about which rows a filter selects.
  bool includes(Transaction transaction) {
    if (!isValid) return false;
    if (!type.matches(transaction)) return false;
    if (memberId != null && transaction.memberId != memberId) return false;
    if (categoryId != null && transaction.categoryId != categoryId) return false;

    final day = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    if (day.isBefore(from) || day.isAfter(to)) return false;
    return true;
  }

  /// The filtered window, newest first (the order the list screens use).
  List<Transaction> apply(List<Transaction> rows) {
    final kept = rows.where(includes).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return kept;
  }
}