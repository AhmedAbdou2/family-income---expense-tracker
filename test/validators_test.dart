import 'package:family_income_expense_tracker/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.displayName', () {
    test('accepts 1-40 chars around trims', () {
      expect(Validators.displayName('A'), isNull);
      expect(Validators.displayName('  Sara  '), isNull);
      expect(Validators.displayName('x' * 40), isNull);
    });

    test('rejects empty / whitespace-only', () {
      expect(Validators.displayName(null), 'required');
      expect(Validators.displayName(''), 'required');
      expect(Validators.displayName('   '), 'required');
    });

    test('rejects more than 40 characters', () {
      expect(Validators.displayName('x' * 41), 'too_long');
    });
  });
}
