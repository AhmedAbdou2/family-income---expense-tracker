import 'package:family_income_expense_tracker/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.minorUnitsToDecimalString / decimalStringToMinorUnits', () {
    test('round trips common values', () {
      for (final units in [0, 1, 99, 100, 12345, 999999, 123456789, -500]) {
        final text = Money.minorUnitsToDecimalString(units);
        expect(Money.decimalStringToMinorUnits(text), units, reason: text);
      }
    });

    test('formats without double math', () {
      expect(Money.minorUnitsToDecimalString(0), '0.00');
      expect(Money.minorUnitsToDecimalString(5), '0.05');
      expect(Money.minorUnitsToDecimalString(50), '0.50');
      expect(Money.minorUnitsToDecimalString(1234567), '12345.67');
      expect(Money.minorUnitsToDecimalString(-1234567), '-12345.67');
    });

    test('parses decimals with 0-2 fraction digits', () {
      expect(Money.decimalStringToMinorUnits('12'), 1200);
      expect(Money.decimalStringToMinorUnits('12.5'), 1250);
      expect(Money.decimalStringToMinorUnits('12.55'), 1255);
      expect(Money.decimalStringToMinorUnits('0.01'), 1);
      expect(Money.decimalStringToMinorUnits('-3.37'), -337);
    });

    test('rejects malformed input', () {
      expect(() => Money.decimalStringToMinorUnits('12.345'), throwsFormatException);
      expect(() => Money.decimalStringToMinorUnits('abc'), throwsFormatException);
      expect(() => Money.decimalStringToMinorUnits('1.2.3'), throwsFormatException);
      expect(() => Money.decimalStringToMinorUnits(''), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('groups thousands and keeps two decimals', () {
      expect(Money.format(minorUnits: 123456789), '1,234,567.89');
      expect(Money.format(minorUnits: 100), '1.00');
      expect(Money.format(minorUnits: -100000), '-1,000.00');
      expect(Money.format(minorUnits: 123456789, currencyCode: 'SAR'), '1,234,567.89 SAR');
    });

    test('converts to Arabic-Indic digits on demand', () {
      expect(Money.format(minorUnits: 1234567, arabicDigits: true), '١٢,٣٤٥.٦٧');
      expect(Money.toArabicIndic('Order 42'), 'Order ٤٢');
    });
  });
}
