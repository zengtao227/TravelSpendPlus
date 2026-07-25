import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/backup.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';

void main() {
  final alice = const Participant(id: 'p1', name: 'Alice');
  final bob = const Participant(id: 'p2', name: 'Bob');

  Trip makeTrip() => Trip(
        id: 't1',
        name: 'Japan',
        startDate: DateTime.utc(2026, 10, 5),
        endDate: DateTime.utc(2026, 10, 12),
        homeCurrency: 'CNY',
        totalBudget: Money.fromMajor(20000, 'CNY'),
        participants: [alice, bob],
      );

  Expense makeExpense() => Expense(
        id: 'e1',
        tripId: 't1',
        category: 'food',
        amount: Money.fromMajor(10000, 'JPY'),
        amountInHomeCurrency: Money.fromMajor(500, 'CNY'),
        description: 'Dinner, with a comma',
        date: DateTime.utc(2026, 10, 6),
        endDate: DateTime.utc(2026, 10, 8),
        location: 'Kyoto',
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice, bob],
      );

  test('tripBundleToJson then tripBundleFromJson round-trips a trip with an expense and a rate',
      () {
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: [makeExpense()],
      exchangeRates: const [ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05)],
    );

    final restored = tripBundleFromJson(tripBundleToJson(bundle));

    expect(restored.trip.id, 't1');
    expect(restored.trip.name, 'Japan');
    expect(restored.trip.startDate, DateTime.utc(2026, 10, 5));
    expect(restored.trip.endDate, DateTime.utc(2026, 10, 12));
    expect(restored.trip.homeCurrency, 'CNY');
    expect(restored.trip.totalBudget, Money.fromMajor(20000, 'CNY'));
    expect(restored.trip.participants.map((p) => p.id).toSet(), {'p1', 'p2'});

    expect(restored.expenses, hasLength(1));
    final e = restored.expenses.single;
    expect(e.id, 'e1');
    expect(e.category, 'food');
    expect(e.amount, Money.fromMajor(10000, 'JPY'));
    expect(e.amountInHomeCurrency, Money.fromMajor(500, 'CNY'));
    expect(e.description, 'Dinner, with a comma');
    expect(e.date, DateTime.utc(2026, 10, 6));
    expect(e.endDate, DateTime.utc(2026, 10, 8));
    expect(e.location, 'Kyoto');
    expect(e.status, ExpenseStatus.actual);
    expect(e.paidBy.id, 'p1');
    expect(e.paidFor.map((p) => p.id).toSet(), {'p1', 'p2'});

    expect(restored.exchangeRates, hasLength(1));
    expect(restored.exchangeRates.single.fromCurrency, 'JPY');
    expect(restored.exchangeRates.single.toCurrency, 'CNY');
    expect(restored.exchangeRates.single.rate, 0.05);
  });

  test('customCategories round-trips through tripBundleToJson/tripBundleFromJson', () {
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: const [],
      exchangeRates: const [],
      customCategories: const ['Souvenirs', 'Visa fee'],
    );

    final restored = tripBundleFromJson(tripBundleToJson(bundle));
    expect(restored.customCategories, ['Souvenirs', 'Visa fee']);
  });

  test('tripBundleFromJson defaults customCategories to empty when the key is absent '
      '(a v1 backup, made before this field existed)', () {
    final json = tripBundleToJson(TripBundle(trip: makeTrip(), expenses: const [], exchangeRates: const []));
    json.remove('customCategories');

    final restored = tripBundleFromJson(json);
    expect(restored.customCategories, isEmpty);
  });

  test('tripBundleFromJson defaults an expense\'s endDate to its date and location to empty '
      'when both keys are absent (a pre-v3 backup, made before those fields existed)', () {
    final json = tripBundleToJson(
      TripBundle(trip: makeTrip(), expenses: [makeExpense()], exchangeRates: const []),
    );
    final expenseJson = (json['expenses'] as List).single as Map<String, dynamic>;
    expenseJson.remove('endDate');
    expenseJson.remove('location');

    final restored = tripBundleFromJson(json);
    final e = restored.expenses.single;
    expect(e.endDate, e.date);
    expect(e.location, '');
  });

  test('a planned expense and a whole-number exchange rate round-trip correctly '
      '(JSON decodes whole numbers as int, not double — the rate parser must handle both)',
      () {
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: [
        makeExpense().copyWith(status: ExpenseStatus.planned, includeInSplit: false),
      ],
      exchangeRates: const [ExchangeRate(fromCurrency: 'USD', toCurrency: 'CNY', rate: 7)],
    );

    final restored = tripBundleFromJson(tripBundleToJson(bundle));

    expect(restored.expenses.single.status, ExpenseStatus.planned);
    expect(restored.expenses.single.includeInSplit, isFalse);
    expect(restored.exchangeRates.single.rate, 7.0);
  });

  test('backupToJson wraps trips with a schemaVersion and backupFromJson unwraps them', () {
    final bundle = TripBundle(trip: makeTrip(), expenses: [], exchangeRates: const []);

    final json = backupToJson([bundle]);
    expect(json['schemaVersion'], kBackupSchemaVersion);
    expect(json['trips'], hasLength(1));

    final restored = backupFromJson(json);
    expect(restored, hasLength(1));
    expect(restored.single.trip.id, 't1');
  });

  test('backupFromJson rejects a schemaVersion newer than this app understands', () {
    final json = {
      'schemaVersion': kBackupSchemaVersion + 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'trips': <Map<String, dynamic>>[],
    };
    expect(() => backupFromJson(json), throwsA(isA<UnsupportedBackupVersionException>()));
  });

  test('an empty trip (no expenses, no rates) round-trips fine', () {
    final bundle = TripBundle(trip: makeTrip(), expenses: [], exchangeRates: const []);
    final restored = tripBundleFromJson(tripBundleToJson(bundle));
    expect(restored.expenses, isEmpty);
    expect(restored.exchangeRates, isEmpty);
  });

  group('expensesToCsv', () {
    Expense expenseWith({required String description, required double amountMajor}) => Expense(
          id: 'e-$description',
          tripId: 't1',
          category: 'food',
          amount: Money.fromMajor(amountMajor, 'JPY'),
          amountInHomeCurrency: Money.fromMajor(amountMajor * 0.05, 'CNY'),
          description: description,
          date: DateTime.utc(2026, 10, 6),
          endDate: DateTime.utc(2026, 10, 6),
          location: '',
          status: ExpenseStatus.actual,
          includeInSplit: true,
          paidBy: alice,
          paidFor: [alice],
        );

    String label(String key) => key == 'food' ? 'Food' : key;
    String status(ExpenseStatus s) => s == ExpenseStatus.actual ? 'Actual' : 'Planned';
    const headers = [
      'Date',
      'End Date',
      'Category',
      'Status',
      'Description',
      'Location',
      'Amount',
      'Currency',
      'In CNY',
    ];

    test('produces a header row plus one row per expense', () {
      final csv = expensesToCsv(
        [expenseWith(description: 'Ramen', amountMajor: 1000)],
        headers: headers,
        categoryLabel: label,
        statusLabel: status,
      );
      final lines = csv.trim().split('\r\n');
      expect(lines, hasLength(2));
      expect(lines[0], 'Date,End Date,Category,Status,Description,Location,Amount,Currency,In CNY');
      expect(lines[1], '2026-10-06,2026-10-06,Food,Actual,Ramen,,1000.00,JPY,50.00');
    });

    test('escapes a description containing a comma', () {
      final csv = expensesToCsv(
        [expenseWith(description: 'Ramen, extra egg', amountMajor: 1000)],
        headers: headers,
        categoryLabel: label,
        statusLabel: status,
      );
      expect(csv, contains('"Ramen, extra egg"'));
    });

    test('an empty expense list produces just the header row', () {
      final csv = expensesToCsv([], headers: headers, categoryLabel: label, statusLabel: status);
      expect(csv.trim().split('\r\n'), hasLength(1));
    });
  });
}
