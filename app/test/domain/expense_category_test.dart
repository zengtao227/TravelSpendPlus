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

  test('category settings serialize their immutable key and optional presentation fields', () {
    const setting = CategorySetting(
      key: 'Souvenirs',
      displayName: 'Gifts',
      iconKey: 'gifts',
      hidden: true,
    );

    expect(CategorySetting.fromJson(setting.toJson()), setting);
    expect(CategorySetting.fromJson(const {'key': 'food'}),
        const CategorySetting(key: 'food'));
  });
}
