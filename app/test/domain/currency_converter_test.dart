import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/currency_converter.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/money.dart';

void main() {
  final rates = [
    const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05),
    const ExchangeRate(fromCurrency: 'USD', toCurrency: 'CNY', rate: 7.2),
  ];

  test('same currency is returned unchanged', () {
    final amount = Money.fromMajor(100, 'CNY');
    final result = CurrencyConverter.convert(
        amount: amount, toCurrency: 'CNY', rates: rates, homeCurrency: 'CNY');
    expect(result, amount);
  });

  test('foreign to home uses the matching rate directly', () {
    final result = CurrencyConverter.convert(
      amount: Money.fromMajor(1000, 'JPY'),
      toCurrency: 'CNY',
      rates: rates,
      homeCurrency: 'CNY',
    );
    expect(result, Money.fromMajor(50, 'CNY'));
  });

  test('home to foreign inverts the matching rate', () {
    final result = CurrencyConverter.convert(
      amount: Money.fromMajor(50, 'CNY'),
      toCurrency: 'JPY',
      rates: rates,
      homeCurrency: 'CNY',
    );
    expect(result.currencyCode, 'JPY');
    expect(result.major, closeTo(1000, 0.01));
  });

  test('foreign to foreign chains through home currency', () {
    final result = CurrencyConverter.convert(
      amount: Money.fromMajor(1000, 'JPY'), // = 50 CNY
      toCurrency: 'USD',
      rates: rates,
      homeCurrency: 'CNY',
    );
    expect(result.currencyCode, 'USD');
    expect(result.major, closeTo(50 / 7.2, 0.01));
  });

  test('throws a clear error when no rate exists for the requested currency', () {
    expect(
      () => CurrencyConverter.convert(
        amount: Money.fromMajor(10, 'GBP'),
        toCurrency: 'CNY',
        rates: rates,
        homeCurrency: 'CNY',
      ),
      throwsArgumentError,
    );
  });
}
