import '../../../core/utils/money.dart';
import '../../transactions/domain/entities.dart';

/// CSV writing, kept pure and language-agnostic (no l10n, no Flutter): the
/// screen resolves the household's own names first and the tests can pin the
/// exact bytes.
///
/// Rules:
///   * UTF-8 BOM first, so Excel opens Arabic/Umrah text correctly.
///   * RFC 4180 quoting (`"` doubled, fields with `,`/`"`/newlines quoted).
///   * CRLF line endings.
///   * A cell that starts with a spreadsheet formula trigger (`=`, `+`,
///     `-`, `@`) or with a tab / carriage return is prefixed with an
///     apostrophe, so a note like `=1+1` or `@SUM(A1)` is text, never a
///     formula (CSV injection guard - AMENDMENT E).
const String csvBom = '\uFEFF';

/// Characters that make a spreadsheet treat a cell as a formula.
const List<String> csvFormulaTriggers = ['=', '+', '-', '@', '\t', '\r'];

/// Header row of every export. English on purpose: the numbers are the
/// household's, the words are a stable machine-readable contract.
const List<String> csvHeader = [
  'date',
  'type',
  'category',
  'person',
  'amount',
  'currency',
  'vehicle',
  'pet',
  'note',
];

/// One cell, already guarded and quoted.
String csvCell(String raw) {
  var value = raw;
  if (value.isNotEmpty &&
      csvFormulaTriggers.any((trigger) => value.startsWith(trigger))) {
    value = "'$value";
  }
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    value = '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Rows (header first) to the finished document.
String buildCsv(List<List<String>> rows) {
  final buffer = StringBuffer()..write(csvBom);
  for (final row in rows) {
    buffer
      ..write(row.map(csvCell).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}

/// Maps transactions to CSV rows. [categoryNames], [memberNames],
/// [vehicleNames] and [petNames] are id -> display name; an unknown id
/// renders as an empty cell.
List<List<String>> csvRowsFor({
  required List<Transaction> transactions,
  required Map<String, String> categoryNames,
  required Map<String, String> memberNames,
  required String currency,
  Map<String, String> vehicleNames = const {},
  Map<String, String> petNames = const {},
}) {
  return [
    csvHeader,
    for (final transaction in transactions)
      [
        _date(transaction.date),
        transaction.type.dbValue,
        categoryNames[transaction.categoryId] ?? '',
        memberNames[transaction.memberId] ?? '',
        Money.minorUnitsToDecimalString(transaction.amountMinorUnits),
        currency,
        transaction.vehicleId == null
            ? ''
            : vehicleNames[transaction.vehicleId] ?? '',
        transaction.petId == null ? '' : petNames[transaction.petId] ?? '',
        transaction.note ?? '',
      ],
  ];
}

String _date(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';