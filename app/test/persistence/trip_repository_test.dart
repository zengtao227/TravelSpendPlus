import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = TripRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  final alice = Participant(id: 'p1', name: 'Alice');
  final bob = Participant(id: 'p2', name: 'Bob');

  Trip makeTrip() => Trip(
        id: 't1',
        name: 'Japan',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
        homeCurrency: 'EUR',
        totalBudget: Money.fromMajor(1000.00, 'EUR'),
        participants: [alice, bob],
      );

  test('createTrip then getTrip round-trips all fields including participants', () async {
    final trip = makeTrip();
    await repo.createTrip(trip);

    final loaded = await repo.getTrip('t1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Japan');
    expect(loaded.homeCurrency, 'EUR');
    expect(loaded.totalBudget, Money.fromMajor(1000.00, 'EUR'));
    expect(loaded.startDate, DateTime(2026, 1, 1));
    expect(loaded.endDate, DateTime(2026, 1, 10));
    expect(loaded.participants.map((p) => p.name).toSet(), {'Alice', 'Bob'});
  });

  test('getTrip returns null for an unknown id', () async {
    final loaded = await repo.getTrip('nonexistent');
    expect(loaded, isNull);
  });

  test('addExpense then getExpenses round-trips a multi-payer expense', () async {
    await repo.createTrip(makeTrip());
    final expense = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(30.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 2),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    await repo.addExpense(expense);

    final loaded = await repo.getExpenses('t1');
    expect(loaded.length, 1);
    expect(loaded.first.category, 'Food');
    expect(loaded.first.amount, Money.fromMajor(30.00, 'EUR'));
    expect(loaded.first.paidBy, alice);
    expect(loaded.first.paidFor.map((p) => p.id).toSet(), {'p1', 'p2'});
    expect(loaded.first.status, ExpenseStatus.actual);
  });

  test('a stored row with an empty paidForIds (e.g. legacy data predating '
      "Expense's empty-paidFor rejection) fails loudly with a clear "
      "ArgumentError, not a confusing null-check crash on participant id ''", () async {
    await repo.createTrip(makeTrip());
    // Insert directly via the Companion, bypassing Expense's constructor
    // (which now rejects an empty paidFor) — simulates data written before
    // that validation existed. ''.split(',') would otherwise return ['']
    // and crash looking up a participant with id '' rather than either
    // recovering as [] or failing with a clear message.
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e-legacy',
          tripId: 't1',
          category: 'Food',
          amountMinorUnits: 1000,
          amountCurrency: 'EUR',
          amountInHomeCurrencyMinorUnits: 1000,
          description: 'legacy row',
          date: DateTime(2026, 1, 2),
          status: 'actual',
          includeInSplit: true,
          paidById: 'p1',
          paidForIds: '',
        ));

    await expectLater(repo.getExpenses('t1'), throwsA(isA<ArgumentError>()));
  });

  test('updateExpense overwrites an existing expense', () async {
    await repo.createTrip(makeTrip());
    final expense = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(30.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 2),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    await repo.addExpense(expense);

    final actualized = expense.convertToActual(
      actualAmount: Money.fromMajor(35.00, 'EUR'),
      actualAmountInHomeCurrency: Money.fromMajor(35.00, 'EUR'),
    );
    await repo.updateExpense(actualized);

    final loaded = await repo.getExpenses('t1');
    expect(loaded.length, 1);
    expect(loaded.first.status, ExpenseStatus.actual);
    expect(loaded.first.amount, Money.fromMajor(35.00, 'EUR'));
  });

  test('getAllTrips returns an empty list when there are no trips', () async {
    expect(await repo.getAllTrips(), isEmpty);
  });

  test('getAllTrips returns every trip with its participants', () async {
    await repo.createTrip(makeTrip());
    final secondTrip = Trip(
      id: 't2',
      name: 'Italy',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 5),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(500, 'EUR'),
      // A distinct participant id, not `alice` — Participants.id is a
      // globally unique primary key (each trip mints its own participant
      // ids in the real app), so reusing `alice`'s id ('p1') across two
      // independently created trips would violate that uniqueness and
      // fail in createTrip's setup, before getAllTrips is ever exercised.
      participants: [Participant(id: 'p3', name: 'Carol')],
    );
    await repo.createTrip(secondTrip);

    final trips = await repo.getAllTrips();
    expect(trips.length, 2);
    expect(trips.map((t) => t.name).toSet(), {'Japan', 'Italy'});
  });

  test('updateTrip changes name, dates, and budget but not participants', () async {
    final trip = makeTrip();
    await repo.createTrip(trip);
    final updated = Trip(
      id: trip.id,
      name: 'Japan (renamed)',
      startDate: DateTime(2026, 10, 6),
      endDate: DateTime(2026, 10, 13),
      homeCurrency: trip.homeCurrency,
      totalBudget: Money.fromMajor(3000, trip.homeCurrency),
      participants: trip.participants,
    );
    await repo.updateTrip(updated);

    final reloaded = await repo.getTrip(trip.id);
    expect(reloaded!.name, 'Japan (renamed)');
    expect(reloaded.startDate, DateTime(2026, 10, 6));
    expect(reloaded.totalBudget, Money.fromMajor(3000, trip.homeCurrency));
  });

  test('setExchangeRate then getExchangeRates round-trips, and re-setting the same currency replaces it',
      () async {
    await repo.createTrip(makeTrip());
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0062));
    var rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.rate, 0.0062);

    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0065));
    rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1, reason: 'setting the same currency again should replace, not duplicate');
    expect(rates.first.rate, 0.0065);
  });

  test('changeHomeCurrency rescales the budget, every expense, and an unrelated rate', () async {
    await repo.createTrip(makeTrip()); // EUR home currency, 1000 EUR budget
    // USD is unrelated to the currency change below (EUR -> JPY) — its rate
    // must be rescaled (still meaningful: "1 USD = ? JPY" after the change),
    // not deleted. The self-referential case (a rate entry for the currency
    // you're changing *to*) is covered by the next test.
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'USD', toCurrency: 'EUR', rate: 0.92));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));

    // 1 EUR = 155 JPY
    await repo.changeHomeCurrency(tripId: 't1', newCurrency: 'JPY', oldToNewRate: 155);

    final trip = await repo.getTrip('t1');
    expect(trip!.homeCurrency, 'JPY');
    expect(trip.totalBudget.major, closeTo(1000 * 155, 0.01));

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amountInHomeCurrency.currencyCode, 'JPY');
    expect(expenses.first.amountInHomeCurrency.major, closeTo(30 * 155, 0.01));

    final rates = await repo.getExchangeRates('t1');
    // 2 rows now: the rescaled unrelated USD rate, plus a fresh EUR->JPY
    // reverse rate preserving the old home currency (see the dedicated
    // reverse-rate test below).
    expect(rates.length, 2);
    final usd = rates.firstWhere((r) => r.fromCurrency == 'USD');
    expect(usd.toCurrency, 'JPY');
    expect(usd.rate, closeTo(0.92 * 155, 0.0001));
    final eur = rates.firstWhere((r) => r.fromCurrency == 'EUR');
    expect(eur.toCurrency, 'JPY');
    expect(eur.rate, 155);
  });

  test('changeHomeCurrency deletes (not rescales) a rate entry for the currency being switched to, '
      'but keeps a reverse rate for the old home currency', () async {
    await repo.createTrip(makeTrip()); // EUR home currency
    // A pre-existing "1 JPY = 0.0062 EUR" rate becomes meaningless the
    // moment JPY itself becomes the home currency — rescaling it would
    // produce a self-referential "1 JPY = X JPY" row that can never be
    // cleaned up later (this app has no delete-a-single-rate flow).
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0062));

    await repo.changeHomeCurrency(tripId: 't1', newCurrency: 'JPY', oldToNewRate: 155);

    final rates = await repo.getExchangeRates('t1');
    // The stale JPY row is gone, but a fresh "1 EUR = 155 JPY" row must
    // exist — otherwise the old home currency (EUR) becomes unusable for
    // any future expense or view-currency switch without manually
    // re-entering a rate the app already knows.
    expect(rates.length, 1);
    expect(rates.first.fromCurrency, 'EUR');
    expect(rates.first.toCurrency, 'JPY');
    expect(rates.first.rate, 155);
  });

  test('changeHomeCurrency rejects a "change" to the currency the trip already uses', () async {
    await repo.createTrip(makeTrip()); // EUR home currency
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));

    await expectLater(
      repo.changeHomeCurrency(tripId: 't1', newCurrency: 'EUR', oldToNewRate: 2.0),
      throwsArgumentError,
    );

    // Nothing should have been touched — not the budget, not the expense.
    final trip = await repo.getTrip('t1');
    expect(trip!.totalBudget, Money.fromMajor(1000, 'EUR'));
    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amountInHomeCurrency, Money.fromMajor(30, 'EUR'));
  });
}
