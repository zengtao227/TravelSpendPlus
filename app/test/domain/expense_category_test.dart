import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/expense_category.dart';

void main() {
  test('exactly the six fixed category keys, in a stable order', () {
    expect(kExpenseCategoryKeys,
        ['food', 'transport', 'lodging', 'shopping', 'entertainment', 'other']);
  });
}
