import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';

void main() {
  group('Money construction', () {
    test('fromMajor converts to minor units correctly', () {
      final m = Money.fromMajor(12.34, 'EUR');
      expect(m.minorUnits, 1234);
      expect(m.currencyCode, 'EUR');
    });

    test('major getter converts back to major units', () {
      final m = Money(minorUnits: 1234, currencyCode: 'EUR');
      expect(m.major, closeTo(12.34, 0.001));
    });

    test('fromMajor rounds to the nearest cent', () {
      final m = Money.fromMajor(12.345, 'EUR');
      expect(m.minorUnits, 1235); // rounds half up
    });
  });

  group('Money arithmetic', () {
    test('addition of same currency', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(5.50, 'EUR');
      expect((a + b).minorUnits, 1550);
    });

    test('subtraction of same currency', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(3.00, 'EUR');
      expect((a - b).minorUnits, 700);
    });

    test('addition of different currencies throws', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(10.00, 'USD');
      expect(() => a + b, throwsArgumentError);
    });

    test('unary negation', () {
      final a = Money.fromMajor(10.00, 'EUR');
      expect((-a).minorUnits, -1000);
    });

    test('dividedBy divides toward the nearest cent', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final result = a.dividedBy(4);
      expect(result.minorUnits, 250);
    });
  });

  group('Money comparison', () {
    test('equality is by value', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(10.00, 'EUR');
      expect(a, equals(b));
    });

    test('equality requires same currency', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(10.00, 'USD');
      expect(a == b, isFalse);
    });

    test('ordering within same currency', () {
      final a = Money.fromMajor(5.00, 'EUR');
      final b = Money.fromMajor(10.00, 'EUR');
      expect(a < b, isTrue);
      expect(b > a, isTrue);
    });
  });

  group('splitEvenly', () {
    test('splits evenly when divisible with no remainder', () {
      final total = Money.fromMajor(9.00, 'EUR');
      final shares = splitEvenly(total, 3);
      expect(shares.length, 3);
      expect(shares.every((s) => s.minorUnits == 300), isTrue);
    });

    test('distributes the remainder deterministically so shares sum exactly to the total', () {
      // 100 cents / 3 = 33.33..., so shares must be [34, 33, 33] (first N get the extra cent)
      final total = Money(minorUnits: 100, currencyCode: 'EUR');
      final shares = splitEvenly(total, 3);
      expect(shares.map((s) => s.minorUnits), [34, 33, 33]);
      final sum = shares.fold<int>(0, (acc, s) => acc + s.minorUnits);
      expect(sum, 100);
    });

    test('splitting into 1 part returns the whole amount', () {
      final total = Money.fromMajor(50.00, 'EUR');
      final shares = splitEvenly(total, 1);
      expect(shares, [total]);
    });

    test('splitting by zero parts throws', () {
      final total = Money.fromMajor(50.00, 'EUR');
      expect(() => splitEvenly(total, 0), throwsArgumentError);
    });
  });
}
