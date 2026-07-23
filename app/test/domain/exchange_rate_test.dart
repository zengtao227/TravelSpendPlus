import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';

void main() {
  test('converts an amount using the given rate', () {
    final rate = ExchangeRate(fromCurrency: 'USD', toCurrency: 'EUR', rate: 0.92);
    final usd = Money.fromMajor(100.00, 'USD');
    final eur = rate.convert(usd);
    expect(eur.currencyCode, 'EUR');
    expect(eur.major, closeTo(92.00, 0.01));
  });

  test('converting an amount in the wrong currency throws', () {
    final rate = ExchangeRate(fromCurrency: 'USD', toCurrency: 'EUR', rate: 0.92);
    final gbp = Money.fromMajor(100.00, 'GBP');
    expect(() => rate.convert(gbp), throwsArgumentError);
  });

  test('identity rate (same currency) returns an equal amount', () {
    final rate = ExchangeRate(fromCurrency: 'EUR', toCurrency: 'EUR', rate: 1.0);
    final eur = Money.fromMajor(50.00, 'EUR');
    expect(rate.convert(eur), Money.fromMajor(50.00, 'EUR'));
  });
}
