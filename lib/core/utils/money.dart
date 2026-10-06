/// Money helpers. House money is ALWAYS integer minor units (e.g. fils,
/// cents) in Dart logic - never `double` math. See AGENTS.md.
abstract final class Money {
  /// Converts integer minor units to a plain decimal string with exactly
  /// two decimals, e.g. `1234567` -> `'12345.67'`. String-safe: no float
  /// arithmetic is performed on the way.
  static String minorUnitsToDecimalString(int minorUnits) {
    final negative = minorUnits < 0;
    final abs = minorUnits.abs();
    final major = abs ~/ 100;
    final cents = (abs % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$major.$cents';
  }

  /// Parses `'12345.67'` into `1234567` minor units. Throws [FormatException]
  /// on anything that is not a plain decimal with 0-2 decimals.
  static int decimalStringToMinorUnits(String value) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
    if (match == null) throw FormatException('Invalid money value: $value');
    final cents = (match.group(3) ?? '').padRight(2, '0');
    final result = int.parse(match.group(2)!) * 100 + int.parse(cents);
    return match.group(1) == '-' ? -result : result;
  }

  static const List<String> _latinToArabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// Renders minor units with grouping: `1234567` -> `'12,345.67'`, or
  /// Arabic-Indic digits `'12,345.67' -> '١٢,٣٤٥٫٦٧'` when [arabicDigits].
  static String format({
    required int minorUnits,
    bool arabicDigits = false,
    String? currencyCode,
  }) {
    final decimal = minorUnitsToDecimalString(minorUnits);
    final negative = decimal.startsWith('-');
    final unsigned = negative ? decimal.substring(1) : decimal;
    final parts = unsigned.split('.');
    final digits = parts[0].replaceAllMapped(
      RegExp(r'\d{1,3}(?=(\d{3})+$)'),
      (m) => '${m[0]},',
    );
    var out = '$digits.${parts[1]}';
    if (currencyCode != null && currencyCode.isNotEmpty) {
      out = '$out $currencyCode';
    }
    if (negative) out = '-$out';
    return arabicDigits ? toArabicIndic(out) : out;
  }

  /// Converts Western digits in [text] to Arabic-Indic digits (٠-٩).
  static String toArabicIndic(String text) => text.replaceAllMapped(
        RegExp(r'\d'),
        (m) => _latinToArabic[int.parse(m[0]!)],
      );
}
