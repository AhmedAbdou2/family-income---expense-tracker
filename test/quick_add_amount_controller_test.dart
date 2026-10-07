import 'package:family_income_expense_tracker/features/transactions/presentation/quick_add_amount_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickAddAmountController', () {
    test('starts empty: display 0, no minor units, save disabled', () {
      final amount = QuickAddAmountController();
      expect(amount.raw, isEmpty);
      expect(amount.display, '0');
      expect(amount.minorUnits, isNull);
      expect(amount.canSave, isFalse);
    });

    test('digits build a raw decimal string and minor units', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('1')
        ..inputDigit('2')
        ..inputDigit('3')
        ..inputDecimal()
        ..inputDigit('4')
        ..inputDigit('5');
      expect(amount.raw, '123.45');
      expect(amount.minorUnits, 12345);
      expect(amount.canSave, isTrue);
    });

    test('decimal with no digits after it does not parse yet', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('7')
        ..inputDecimal();
      expect(amount.raw, '7.');
      expect(amount.minorUnits, isNull);
      expect(amount.canSave, isFalse);
    });

    test('decimal point alone stays unsaveable', () {
      final amount = QuickAddAmountController();
      amount.inputDecimal();
      expect(amount.raw, '0.');
      expect(amount.minorUnits, isNull);
      expect(amount.canSave, isFalse);
    });

    test('zero is not saveable', () {
      final amount = QuickAddAmountController();
      amount.inputDigit('0');
      expect(amount.minorUnits, 0);
      expect(amount.canSave, isFalse);
    });

    test('leading zero is replaced by the next digit', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('0')
        ..inputDigit('5');
      expect(amount.raw, '5');
    });

    test('caps at 9 integer digits and 2 decimals', () {
      final amount = QuickAddAmountController();
      for (var i = 0; i < 12; i++) {
        amount.inputDigit('9');
      }
      expect(amount.raw, '999999999');

      amount
        ..inputDecimal()
        ..inputDigit('1')
        ..inputDigit('2')
        ..inputDigit('3');
      expect(amount.raw, '999999999.12');
      expect(amount.minorUnits, 99999999912);
    });

    test('only one decimal point is accepted', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('1')
        ..inputDecimal()
        ..inputDigit('2')
        ..inputDecimal();
      expect(amount.raw, '1.2');
    });

    test('backspace erases one character, empty stays empty', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('4')
        ..inputDigit('2');
      amount.backspace();
      expect(amount.raw, '4');
      amount.backspace();
      amount.backspace();
      expect(amount.raw, isEmpty);
      expect(amount.display, '0');
    });

    test('clear resets everything', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('8')
        ..inputDecimal()
        ..inputDigit('5')
        ..clear();
      expect(amount.raw, isEmpty);
      expect(amount.canSave, isFalse);
    });

    test('never touches double parsing (money stays integer)', () {
      final amount = QuickAddAmountController();
      amount
        ..inputDigit('7')
        ..inputDecimal()
        ..inputDigit('0')
        ..inputDigit('5');
      // 7.05 in decimal arithmetic is exactly 705 minor units.
      expect(amount.raw, '7.05');
      expect(amount.minorUnits, 705);
    });
  });
}
