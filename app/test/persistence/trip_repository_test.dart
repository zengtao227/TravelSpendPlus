import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/backup.dart';
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
    // Dates round-trip as UTC-midnight civil dates (see civil_date.dart) —
    // DateTime's == also checks isUtc, so the expected values must be UTC
    // too, not just numerically matching year/month/day.
    expect(loaded.startDate, DateTime.utc(2026, 1, 1));
    expect(loaded.endDate, DateTime.utc(2026, 1, 10));
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
    expect(reloaded.startDate, DateTime.utc(2026, 10, 6));
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

    // 1 EUR = 155 JPY, and a direct 1 USD = 143.6 JPY (happens to equal the
    // old USD->EUR rate times the EUR->JPY rate here, but is supplied
    // directly rather than derived by chaining through EUR).
    await repo.changeHomeCurrency(
      tripId: 't1',
      newCurrency: 'JPY',
      directRatesToNewCurrency: {'EUR': 155, 'USD': 0.92 * 155},
    );

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

    await repo.changeHomeCurrency(
      tripId: 't1',
      newCurrency: 'JPY',
      directRatesToNewCurrency: {'EUR': 155},
    );

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
      repo.changeHomeCurrency(
        tripId: 't1',
        newCurrency: 'EUR',
        directRatesToNewCurrency: {'EUR': 2.0},
      ),
      throwsArgumentError,
    );

    // Nothing should have been touched — not the budget, not the expense.
    final trip = await repo.getTrip('t1');
    expect(trip!.totalBudget, Money.fromMajor(1000, 'EUR'));
    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amountInHomeCurrency, Money.fromMajor(30, 'EUR'));
  });

  test(
      'changeHomeCurrency converts each currency using its own direct rate, not by chaining '
      'through the old home currency', () async {
    await repo.createTrip(makeTrip()); // EUR home, 1000 EUR budget
    // A JPY expense whose entry-time rate (1 JPY = 0.0065 EUR) implies a
    // transitive JPY->CHF rate of 0.0065 * 155 = 1.0075 if chained through
    // EUR — but the caller supplies a different, real-market direct JPY->CHF
    // rate of 1.02 below, and that direct rate must be what's actually used.
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0065));
    await repo.addExpense(Expense(
      id: 'e-eur',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 3),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));
    await repo.addExpense(Expense(
      id: 'e-jpy',
      tripId: 't1',
      category: 'shopping',
      amount: Money.fromMajor(1000, 'JPY'),
      amountInHomeCurrency: Money.fromMajor(6.5, 'EUR'), // 1000 JPY * 0.0065
      description: 'Souvenirs',
      date: DateTime(2026, 1, 4),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));

    await repo.changeHomeCurrency(
      tripId: 't1',
      newCurrency: 'CHF',
      directRatesToNewCurrency: {'EUR': 155, 'JPY': 1.02},
    );

    final expenses = await repo.getExpenses('t1');
    final eurExpense = expenses.firstWhere((e) => e.id == 'e-eur');
    final jpyExpense = expenses.firstWhere((e) => e.id == 'e-jpy');
    expect(eurExpense.amountInHomeCurrency.currencyCode, 'CHF');
    expect(eurExpense.amountInHomeCurrency.major, closeTo(30 * 155, 0.01));
    // Must use the direct 1000 * 1.02 rate, NOT the chained 1000 * 0.0065 * 155.
    expect(jpyExpense.amountInHomeCurrency.major, closeTo(1000 * 1.02, 0.01));

    final rates = await repo.getExchangeRates('t1');
    final jpyRate = rates.firstWhere((r) => r.fromCurrency == 'JPY');
    expect(jpyRate.toCurrency, 'CHF');
    expect(jpyRate.rate, 1.02);
  });

  test('changeHomeCurrency rejects a missing direct rate for a currency actually in use',
      () async {
    await repo.createTrip(makeTrip()); // EUR home
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0065));

    await expectLater(
      // Only supplies EUR's rate, omitting the required JPY->CHF rate.
      repo.changeHomeCurrency(
        tripId: 't1',
        newCurrency: 'CHF',
        directRatesToNewCurrency: {'EUR': 155},
      ),
      throwsArgumentError,
    );

    final trip = await repo.getTrip('t1');
    expect(trip!.homeCurrency, 'EUR', reason: 'the transaction must not partially apply');
  });

  test('deleteTrip removes the trip and every child row (participants, expenses, rates, '
      'custom categories), leaving other trips untouched', () async {
    final trip = makeTrip();
    await repo.createTrip(trip);
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 3),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.006));
    await repo.addCustomCategory('t1', 'Souvenirs');

    final otherTrip = Trip(
      id: 't2',
      name: 'Korea',
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 5),
      homeCurrency: 'KRW',
      totalBudget: Money.fromMajor(500000, 'KRW'),
      participants: [Participant(id: 'p3', name: 'Carol')],
    );
    await repo.createTrip(otherTrip);

    await repo.deleteTrip('t1');

    expect(await repo.getTrip('t1'), isNull);
    expect(await repo.getExpenses('t1'), isEmpty);
    expect(await repo.getExchangeRates('t1'), isEmpty);
    expect(await repo.getCustomCategories('t1'), isEmpty);
    expect(await repo.getAllTrips(), hasLength(1));
    final remaining = await repo.getTrip('t2');
    expect(remaining, isNotNull);
    expect(remaining!.name, 'Korea');
  });

  test('addCustomCategory then getCustomCategories round-trips, and adding the same name again '
      'does not duplicate it', () async {
    await repo.createTrip(makeTrip());
    await repo.addCustomCategory('t1', 'Souvenirs');
    var categories = await repo.getCustomCategories('t1');
    expect(categories, ['Souvenirs']);

    await repo.addCustomCategory('t1', 'Souvenirs');
    categories = await repo.getCustomCategories('t1');
    expect(categories, ['Souvenirs'], reason: 'adding the same name twice must not duplicate it');
  });

  test('getCustomCategories only returns categories for the given trip', () async {
    await repo.createTrip(makeTrip());
    await repo.createTrip(Trip(
      id: 't2',
      name: 'Korea',
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 5),
      homeCurrency: 'KRW',
      totalBudget: Money.fromMajor(500000, 'KRW'),
      participants: [Participant(id: 'p3', name: 'Carol')],
    ));
    await repo.addCustomCategory('t1', 'Souvenirs');
    await repo.addCustomCategory('t2', 'Visa fee');

    expect(await repo.getCustomCategories('t1'), ['Souvenirs']);
    expect(await repo.getCustomCategories('t2'), ['Visa fee']);
  });

  group('export/import', () {
    test('exportAllTripsToJson then importAllTripsFromJson (into a fresh db) round-trips '
        'a trip with an expense, a rate, and a custom category', () async {
      final trip = makeTrip();
      await repo.createTrip(trip);
      await repo.setExchangeRate(
          trip.id, const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.006));
      await repo.addCustomCategory(trip.id, 'Souvenirs');
      await repo.addExpense(Expense(
        id: 'e1',
        tripId: trip.id,
        category: 'Souvenirs',
        amount: Money.fromMajor(1000, 'JPY'),
        amountInHomeCurrency: Money.fromMajor(6, 'EUR'),
        description: 'Ramen',
        date: DateTime(2026, 1, 2),
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice],
      ));

      final json = await repo.exportAllTripsToJson();

      final freshDb = AppDatabase.memory();
      final freshRepo = TripRepository(freshDb);
      final importedCount = await freshRepo.importAllTripsFromJson(json);
      expect(importedCount, 1);

      final restoredTrip = await freshRepo.getTrip(trip.id);
      expect(restoredTrip, isNotNull);
      expect(restoredTrip!.name, trip.name);
      final restoredExpenses = await freshRepo.getExpenses(trip.id);
      expect(restoredExpenses, hasLength(1));
      expect(restoredExpenses.single.description, 'Ramen');
      expect(restoredExpenses.single.category, 'Souvenirs');
      final restoredRates = await freshRepo.getExchangeRates(trip.id);
      expect(restoredRates, hasLength(1));
      expect(restoredRates.single.fromCurrency, 'JPY');
      final restoredCategories = await freshRepo.getCustomCategories(trip.id);
      expect(restoredCategories, ['Souvenirs']);

      await freshDb.close();
    });

    test('importAllTripsFromJson restores a v1 backup (no customCategories key) with an empty '
        'custom category list, instead of failing', () async {
      final trip = makeTrip();
      final v1Json = {
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'trips': [
          {
            'id': trip.id,
            'name': trip.name,
            'startDate': '2026-01-01',
            'endDate': '2026-01-10',
            'homeCurrency': trip.homeCurrency,
            'totalBudgetMinorUnits': trip.totalBudget.minorUnits,
            'participants': [
              {'id': alice.id, 'name': alice.name},
            ],
            'expenses': <Map<String, dynamic>>[],
            'exchangeRates': <Map<String, dynamic>>[],
            // no 'customCategories' key — this is what a real v1 export looked like
          },
        ],
      };

      final importedCount = await repo.importAllTripsFromJson(v1Json);
      expect(importedCount, 1);
      expect(await repo.getCustomCategories(trip.id), isEmpty);
    });

    test('exportAllTripsToJson with zero trips produces an empty trips list', () async {
      final json = await repo.exportAllTripsToJson();
      expect(json['trips'], isEmpty);
    });

    test('importAllTripsFromJson rejects a backup with a newer schemaVersion', () async {
      final json = {
        'schemaVersion': kBackupSchemaVersion + 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'trips': <Map<String, dynamic>>[],
      };
      expect(
        () => repo.importAllTripsFromJson(json),
        throwsA(isA<UnsupportedBackupVersionException>()),
      );
    });
  });
}
