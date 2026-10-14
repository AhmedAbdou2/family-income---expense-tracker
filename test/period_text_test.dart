import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('ar', null);
  });

  test('buildPeriodText uses Western digits by default', () {
    final text = buildPeriodText(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      locale: 'en',
      arabicDigits: false,
    );
    expect(text, contains('2026'));
  });

  test('buildPeriodText keeps Western digits in English when requested', () {
    final text = buildPeriodText(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      locale: 'en',
      arabicDigits: false,
    );
    expect(text.contains('٠'), isFalse);
    expect(text, contains('2026'));
  });

  test('buildPeriodText converts to Arabic-Indic when arabicDigits is true', () {
    final text = buildPeriodText(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      locale: 'ar',
      arabicDigits: true,
    );
    expect(text, contains('٢٠٢٦'));
    expect(text.contains('٠') || text.contains('٩') || text.contains('٥'), isTrue);
  });

  test('buildPeriodText with Arabic locale and no digits toggle keeps digits format', () {
    final text = buildPeriodText(
      from: DateTime(2026, 6, 1),
      to: DateTime(2026, 6, 30),
      locale: 'ar',
      arabicDigits: false,
    );
    expect(text.contains('–'), isTrue);
  });
}
