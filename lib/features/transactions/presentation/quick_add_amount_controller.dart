import '../../../core/utils/money.dart';

/// Pure keypad logic for the quick-add sheet. Keeps the amount as a raw
/// decimal STRING (never a `double`), so money only ever flows through
/// [Money] - see AGENTS.md. No Flutter imports: unit-testable as-is.
class QuickAddAmountController {
  String _raw = '';

  /// The raw entry, e.g. `'12.5'`, `''` before the first keypress.
  String get raw => _raw;

  /// What the display shows: `'0'` until a digit is pressed.
  String get display => _raw.isEmpty ? '0' : _raw;

  /// Minor units once parseable, null while empty (`''`, `'.'`, ...).
  int? get minorUnits {
    if (_raw.isEmpty || _raw == '.') return null;
    try {
      return Money.decimalStringToMinorUnits(_raw);
    } on FormatException {
      return null;
    }
  }

  /// Save stays disabled until the amount is a positive number.
  bool get canSave => (minorUnits ?? 0) > 0;

  bool get _hasDecimal => _raw.contains('.');
  int get _decimalPlaces => _hasDecimal ? _raw.length - _raw.indexOf('.') - 1 : 0;
  int get _integerDigits => _hasDecimal ? _raw.indexOf('.') : _raw.length;

  void inputDigit(String digit) {
    assert(digit.length == 1 &&
        (digit.codeUnitAt(0) >= 48 && digit.codeUnitAt(0) <= 57));
    if (_hasDecimal && _decimalPlaces >= 2) return;
    if (!_hasDecimal && _integerDigits >= 9) return;

    if (_raw == '0') {
      _raw = digit;
    } else {
      _raw += digit;
    }
  }

  void inputDecimal() {
    if (_hasDecimal) return;
    _raw = _raw.isEmpty ? '0.' : '$_raw.';
  }

  void backspace() {
    _raw = _raw.isEmpty ? '' : _raw.substring(0, _raw.length - 1);
  }

  void clear() => _raw = '';
}
