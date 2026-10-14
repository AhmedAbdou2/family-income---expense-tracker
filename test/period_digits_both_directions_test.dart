import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('ar_EG', null);
  });

  test('period digits both directions', () {
    final textEnWest = buildPeriodText(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      locale: 'ar',
      arabicDigits: false,
    );
    expect(textEnWest.contains('١'), isFalse);
    expect(textEnWest.contains('٠'), isFalse);

    final textArIndic = buildPeriodText(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      locale: 'ar',
      arabicDigits: true,
    );
    expect(textArIndic.contains('١'), isTrue);
    expect(textArIndic.contains('٠'), isTrue);
  });
}
