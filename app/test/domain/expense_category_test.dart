import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/expense_category.dart';

void main() {
  test('exactly the seven fixed category keys, in a stable order', () {
    expect(kExpenseCategoryKeys,
        ['flight', 'lodging', 'food', 'transport', 'shopping', 'entertainment', 'other']);
  });
}
