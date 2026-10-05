import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/expense_category.dart';

void main() {
  test(
    'built-in category keys include drinks and sightseeing in a stable order', () {
    expect(kExpenseCategoryKeys,
        ['flight', 'lodging', 'food',
        'drinks',
        'transport',
        'sightseeing', 'shopping', 'entertainment', 'other']);
  });
}
