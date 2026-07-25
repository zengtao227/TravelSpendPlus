import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/currency_list.dart';

void main() {
  test('common currencies are pinned first, in the requested order', () {
    expect(kCommonCurrencyCodes, ['EUR', 'CHF', 'USD', 'CNY', 'JPY', 'SGD']);
  });

  test('kAllCurrencyCodesOrdered starts with the common list, then the rest', () {
    expect(
      kAllCurrencyCodesOrdered.sublist(0, kCommonCurrencyCodes.length),
      kCommonCurrencyCodes,
    );
    expect(
      kAllCurrencyCodesOrdered.sublist(kCommonCurrencyCodes.length),
      kOtherCurrencyCodes,
    );
  });

  test('no code appears in both the common and other lists', () {
    final overlap = kCommonCurrencyCodes.toSet().intersection(kOtherCurrencyCodes.toSet());
    expect(overlap, isEmpty);
  });

  test('every code is a unique 3-letter uppercase string', () {
    expect(kAllCurrencyCodesOrdered.toSet().length, kAllCurrencyCodesOrdered.length,
        reason: 'no duplicates');
    for (final code in kAllCurrencyCodesOrdered) {
      expect(code.length, 3);
      expect(code, code.toUpperCase());
    }
  });
}
