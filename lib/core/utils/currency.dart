/// Currency display helper.
///
/// The household currency is stored as an ISO-like 3-letter code
/// (`households.currency`, e.g. `EGP`). In the English UI the code itself is
/// shown (`EGP`); in the Arabic UI the currency's Arabic symbol is shown
/// (`ج.م`). Unknown codes always fall back to the code, so a code that has no
/// symbol never renders as an empty string.
abstract final class Currency {
  /// Arabic symbols for every code offered by `kSupportedCurrencies`.
  static const Map<String, String> arabicSymbols = {
    'SAR': 'ر.س',
    'AED': 'د.إ',
    'EGP': 'ج.م',
    'KWD': 'د.ك',
    'QAR': 'ر.ق',
    'OMR': 'ر.ع',
    'BHD': 'د.ب',
    'JOD': 'د.أ',
    'IQD': 'د.ع',
    'YER': 'ر.ي',
    'SDG': 'ج.س',
    'MAD': 'د.م',
    'TND': 'د.ت',
    'DZD': 'د.ج',
    'LBP': 'ل.ل',
    'SYP': 'ل.س',
    'TRY': '₺',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
  };

  /// The label to show next to an amount (or on its own).
  ///
  /// Returns the Arabic symbol for [code] when [locale] is Arabic, otherwise
  /// the code unchanged. A null/empty [code] returns an empty string (callers
  /// such as `Money.format` treat that as "no currency to show").
  static String label(String? code, {String? locale}) {
    final value = code?.trim() ?? '';
    if (value.isEmpty) return '';
    final isArabic = (locale ?? '').toLowerCase().startsWith('ar');
    if (!isArabic) return value;
    return arabicSymbols[value.toUpperCase()] ?? value;
  }
}
