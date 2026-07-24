import 'exchange_rate.dart';
import 'money.dart';

/// Converts [amount] into [toCurrency] using a trip's manually maintained
/// [rates] list, each expressed as "1 fromCurrency = rate homeCurrency"
/// (every rate's `toCurrency` is the trip's [homeCurrency] — see
/// `ExchangeRate`). Unlike `ExchangeRate.convert`, which only converts in
/// the single direction it was defined, this supports any-to-any
/// conversion by routing through [homeCurrency]: foreign->home uses the
/// matching rate directly, home->foreign inverts it, foreign->foreign
/// chains both steps.
class CurrencyConverter {
  static Money convert({
    required Money amount,
    required String toCurrency,
    required List<ExchangeRate> rates,
    required String homeCurrency,
  }) {
    if (amount.currencyCode == toCurrency) return amount;

    final Money inHome;
    if (amount.currencyCode == homeCurrency) {
      inHome = amount;
    } else {
      final forward = rates.firstWhere(
        (r) => r.fromCurrency == amount.currencyCode && r.toCurrency == homeCurrency,
        orElse: () => throw ArgumentError(
          'No exchange rate from ${amount.currencyCode} to $homeCurrency',
        ),
      );
      inHome = forward.convert(amount);
    }

    if (toCurrency == homeCurrency) return inHome;

    final inverse = rates.firstWhere(
      (r) => r.fromCurrency == toCurrency && r.toCurrency == homeCurrency,
      orElse: () =>
          throw ArgumentError('No exchange rate from $toCurrency to $homeCurrency'),
    );
    return ExchangeRate(
      fromCurrency: homeCurrency,
      toCurrency: toCurrency,
      rate: 1 / inverse.rate,
    ).convert(inHome);
  }
}
