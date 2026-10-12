import 'package:family_income_expense_tracker/core/l10n/generated/app_localizations_ar.dart';
import 'package:family_income_expense_tracker/core/l10n/generated/app_localizations_en.dart';
import 'package:family_income_expense_tracker/core/utils/currency.dart';
import 'package:family_income_expense_tracker/features/household/presentation/create_household_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic UI shows the Arabic symbol, English keeps the ISO code', () {
    expect(Currency.label('EGP', locale: 'ar'), 'ج.م');
    expect(Currency.label('EGP', locale: 'en'), 'EGP');
    expect(Currency.label('SAR', locale: 'ar'), 'ر.س');
    expect(Currency.label('SAR', locale: 'en'), 'SAR');
    expect(Currency.label('USD', locale: 'ar'), r'$');
  });

  test('the code match ignores case and surrounding spaces', () {
    expect(Currency.label('egp', locale: 'ar'), 'ج.م');
    expect(Currency.label(' EGP ', locale: 'ar'), 'ج.م');
  });

  test('unknown codes fall back to the code in every locale', () {
    expect(Currency.label('XYZ', locale: 'ar'), 'XYZ');
    expect(Currency.label('XYZ', locale: 'en'), 'XYZ');
  });

  test('a missing currency renders as an empty string (no suffix)', () {
    expect(Currency.label(null, locale: 'ar'), '');
    expect(Currency.label('', locale: 'en'), '');
    expect(Currency.label('   ', locale: 'ar'), '');
  });

  test('every supported currency has a non-empty Arabic symbol', () {
    for (final code in kSupportedCurrencies) {
      expect(Currency.arabicSymbols.containsKey(code), isTrue, reason: code);
      expect(Currency.label(code, locale: 'ar'), isNotEmpty, reason: code);
      expect(Currency.label(code, locale: 'en'), code, reason: code);
    }
  });

  test('every supported currency has a readable name in both languages', () {
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    for (final code in kSupportedCurrencies) {
      expect(en.currency_name(code), isNotEmpty, reason: code);
      expect(ar.currency_name(code), isNotEmpty, reason: code);
      // A known code must resolve to a name, not fall through to the code.
      expect(en.currency_name(code), isNot(code), reason: 'en $code');
      expect(ar.currency_name(code), isNot(code), reason: 'ar $code');
    }
  });
}
