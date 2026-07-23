import 'money.dart';

/// A conversion rate between two currencies: 1 [fromCurrency] = [rate] [toCurrency].
///
/// Entered manually per-expense for now — live rate fetching with offline
/// caching is a deliberately separate, not-yet-built subsystem (see the
/// implementation plan's Global Constraints).
class ExchangeRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;

  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
  });

  Money convert(Money amount) {
    if (amount.currencyCode != fromCurrency) {
      throw ArgumentError(
        'ExchangeRate is from $fromCurrency, cannot convert ${amount.currencyCode}',
      );
    }
    return Money.fromMajor(amount.major * rate, toCurrency);
  }
}
