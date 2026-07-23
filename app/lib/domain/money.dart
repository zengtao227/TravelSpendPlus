/// Money is always stored as integer minor units (cents) to avoid
/// floating-point rounding errors. Never store currency amounts as `double`.
class Money {
  final int minorUnits;
  final String currencyCode;

  const Money({required this.minorUnits, required this.currencyCode});

  factory Money.fromMajor(double amount, String currencyCode) {
    return Money(minorUnits: (amount * 100).round(), currencyCode: currencyCode);
  }

  double get major => minorUnits / 100;

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'Cannot combine $currencyCode and ${other.currencyCode} directly — convert first',
      );
    }
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -() => Money(minorUnits: -minorUnits, currencyCode: currencyCode);

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  Money dividedBy(int n) {
    if (n == 0) throw ArgumentError('Cannot divide Money by zero');
    return Money.fromMajor(major / n, currencyCode);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits && other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => '${major.toStringAsFixed(2)} $currencyCode';
}

/// Splits [total] into [parts] shares that sum exactly to [total.minorUnits]
/// (unlike naive division, which loses or gains cents to rounding). The
/// first `total.minorUnits % parts` shares get one extra minor unit each —
/// deterministic so the same input always splits the same way, which
/// balance calculations rely on for reproducible net-balance math.
List<Money> splitEvenly(Money total, int parts) {
  if (parts <= 0) {
    throw ArgumentError('parts must be positive, got $parts');
  }
  final base = total.minorUnits ~/ parts;
  final remainder = total.minorUnits % parts;
  return List.generate(parts, (i) {
    final extra = i < remainder ? 1 : 0;
    return Money(minorUnits: base + extra, currencyCode: total.currencyCode);
  });
}
