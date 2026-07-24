import 'package:drift/drift.dart';

import '../domain/money.dart';
import '../domain/participant.dart';
import '../domain/trip.dart';
import '../domain/expense.dart';
import '../domain/exchange_rate.dart';
import 'database.dart' hide Trip, Participant, Expense;

class TripRepository {
  final AppDatabase _db;

  TripRepository(this._db);

  Future<void> createTrip(Trip trip) async {
    await _db.into(_db.trips).insert(TripsCompanion.insert(
          id: trip.id,
          name: trip.name,
          startDate: trip.startDate,
          endDate: trip.endDate,
          homeCurrency: trip.homeCurrency,
          totalBudgetMinorUnits: trip.totalBudget.minorUnits,
        ));
    for (final participant in trip.participants) {
      await _db.into(_db.participants).insert(ParticipantsCompanion.insert(
            id: participant.id,
            tripId: trip.id,
            name: participant.name,
          ));
    }
  }

  Future<Trip?> getTrip(String id) async {
    final tripRow = await (_db.select(_db.trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (tripRow == null) return null;

    final participantRows =
        await (_db.select(_db.participants)..where((p) => p.tripId.equals(id))).get();

    return Trip(
      id: tripRow.id,
      name: tripRow.name,
      startDate: tripRow.startDate,
      endDate: tripRow.endDate,
      homeCurrency: tripRow.homeCurrency,
      totalBudget: Money(minorUnits: tripRow.totalBudgetMinorUnits, currencyCode: tripRow.homeCurrency),
      participants: participantRows
          .map((row) => Participant(id: row.id, name: row.name))
          .toList(),
    );
  }

  Future<List<Trip>> getAllTrips() async {
    final tripRows = await _db.select(_db.trips).get();
    final trips = <Trip>[];
    for (final tripRow in tripRows) {
      final participantRows = await (_db.select(_db.participants)
            ..where((p) => p.tripId.equals(tripRow.id)))
          .get();
      trips.add(Trip(
        id: tripRow.id,
        name: tripRow.name,
        startDate: tripRow.startDate,
        endDate: tripRow.endDate,
        homeCurrency: tripRow.homeCurrency,
        totalBudget: Money(
          minorUnits: tripRow.totalBudgetMinorUnits,
          currencyCode: tripRow.homeCurrency,
        ),
        participants:
            participantRows.map((row) => Participant(id: row.id, name: row.name)).toList(),
      ));
    }
    return trips;
  }

  Future<void> updateTrip(Trip trip) async {
    await (_db.update(_db.trips)..where((t) => t.id.equals(trip.id))).write(
      TripsCompanion(
        name: Value(trip.name),
        startDate: Value(trip.startDate),
        endDate: Value(trip.endDate),
        homeCurrency: Value(trip.homeCurrency),
        totalBudgetMinorUnits: Value(trip.totalBudget.minorUnits),
      ),
    );
  }

  // amountInHomeCurrencyMinorUnits has no currency column of its own in the
  // Expenses table (it's always the owning trip's home currency, which
  // doesn't change) — load the trip row once per call and use its
  // homeCurrency directly, instead of guessing from amountCurrency.
  Future<List<Expense>> getExpenses(String tripId) async {
    final tripRow =
        await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (tripRow == null) return [];
    final homeCurrency = tripRow.homeCurrency;

    final expenseRows =
        await (_db.select(_db.expenses)..where((e) => e.tripId.equals(tripId))).get();
    final participantRows =
        await (_db.select(_db.participants)..where((p) => p.tripId.equals(tripId))).get();
    final participantsById = {
      for (final row in participantRows) row.id: Participant(id: row.id, name: row.name),
    };

    return expenseRows.map((row) {
      // ''.split(',') returns [''] (one empty string), not [] — an empty
      // paidForIds must map to an empty list, not a lookup of participant
      // id ''. Expense's own constructor rejects an empty paidFor with a
      // clear ArgumentError, which is what should surface if this ever
      // happens (it shouldn't, now that Expense validates on construction,
      // but stored data could predate that check).
      final paidFor = row.paidForIds.isEmpty
          ? <Participant>[]
          : row.paidForIds.split(',').map((id) => participantsById[id]!).toList();
      return Expense(
        id: row.id,
        tripId: row.tripId,
        category: row.category,
        amount: Money(minorUnits: row.amountMinorUnits, currencyCode: row.amountCurrency),
        amountInHomeCurrency: Money(
          minorUnits: row.amountInHomeCurrencyMinorUnits,
          currencyCode: homeCurrency,
        ),
        description: row.description,
        date: row.date,
        status: row.status == 'actual' ? ExpenseStatus.actual : ExpenseStatus.planned,
        includeInSplit: row.includeInSplit,
        paidBy: participantsById[row.paidById]!,
        paidFor: paidFor,
      );
    }).toList();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.into(_db.expenses).insert(ExpensesCompanion.insert(
          id: expense.id,
          tripId: expense.tripId,
          category: expense.category,
          amountMinorUnits: expense.amount.minorUnits,
          amountCurrency: expense.amount.currencyCode,
          amountInHomeCurrencyMinorUnits: expense.amountInHomeCurrency.minorUnits,
          description: expense.description,
          date: expense.date,
          status: expense.status == ExpenseStatus.actual ? 'actual' : 'planned',
          includeInSplit: expense.includeInSplit,
          paidById: expense.paidBy.id,
          paidForIds: expense.paidFor.map((p) => p.id).join(','),
        ));
  }

  Future<void> updateExpense(Expense expense) async {
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expense.id))).write(
      ExpensesCompanion(
        category: Value(expense.category),
        amountMinorUnits: Value(expense.amount.minorUnits),
        amountCurrency: Value(expense.amount.currencyCode),
        amountInHomeCurrencyMinorUnits: Value(expense.amountInHomeCurrency.minorUnits),
        description: Value(expense.description),
        date: Value(expense.date),
        status: Value(expense.status == ExpenseStatus.actual ? 'actual' : 'planned'),
        includeInSplit: Value(expense.includeInSplit),
        paidById: Value(expense.paidBy.id),
        paidForIds: Value(expense.paidFor.map((p) => p.id).join(',')),
      ),
    );
  }

  Future<List<ExchangeRate>> getExchangeRates(String tripId) async {
    final tripRow =
        await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (tripRow == null) return [];
    final rows = await (_db.select(_db.tripExchangeRates)
          ..where((r) => r.tripId.equals(tripId)))
        .get();
    return rows
        .map((row) => ExchangeRate(
              fromCurrency: row.fromCurrency,
              toCurrency: tripRow.homeCurrency,
              rate: row.rate,
            ))
        .toList();
  }

  Future<void> setExchangeRate(String tripId, ExchangeRate rate) async {
    final existing = await (_db.select(_db.tripExchangeRates)
          ..where((r) => r.tripId.equals(tripId) & r.fromCurrency.equals(rate.fromCurrency)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.tripExchangeRates)..where((r) => r.id.equals(existing.id)))
          .write(TripExchangeRatesCompanion(rate: Value(rate.rate)));
    } else {
      await _db.into(_db.tripExchangeRates).insert(TripExchangeRatesCompanion.insert(
            tripId: tripId,
            fromCurrency: rate.fromCurrency,
            rate: rate.rate,
          ));
    }
  }

  /// Changes a trip's home currency and rescales everything already
  /// denominated in the old one by [oldToNewRate] ("1 old home currency =
  /// oldToNewRate new home currency") — `Expense.amountInHomeCurrency` and
  /// `Trip.totalBudget` are both stored as plain numbers re-labeled with
  /// whatever the trip's *current* home currency is, so simply changing
  /// the label without rescaling the numbers would silently corrupt every
  /// existing total. See docs/superpowers/specs/2026-07-24-travelspendplus-ui-design.md
  /// section 五 for why this replaced an earlier "just clear the rate
  /// table" design.
  Future<void> changeHomeCurrency({
    required String tripId,
    required String newCurrency,
    required double oldToNewRate,
  }) async {
    await _db.transaction(() async {
      final tripRow =
          await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingle();
      final newBudgetMinorUnits =
          (tripRow.totalBudgetMinorUnits * oldToNewRate).round();
      await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          homeCurrency: Value(newCurrency),
          totalBudgetMinorUnits: Value(newBudgetMinorUnits),
        ),
      );

      final expenseRows =
          await (_db.select(_db.expenses)..where((e) => e.tripId.equals(tripId))).get();
      for (final row in expenseRows) {
        final newAmountInHome =
            (row.amountInHomeCurrencyMinorUnits * oldToNewRate).round();
        await (_db.update(_db.expenses)..where((e) => e.id.equals(row.id))).write(
          ExpensesCompanion(amountInHomeCurrencyMinorUnits: Value(newAmountInHome)),
        );
      }

      final rateRows = await (_db.select(_db.tripExchangeRates)
            ..where((r) => r.tripId.equals(tripId)))
          .get();
      for (final row in rateRows) {
        if (row.fromCurrency == newCurrency) {
          // This currency IS the new home currency now — a rescaled "1 X =
          // Y X" row would be self-referential nonsense, and this app has
          // no delete-a-single-rate flow to ever clean it up later, so it
          // must be deleted here rather than rescaled.
          await (_db.delete(_db.tripExchangeRates)..where((r) => r.id.equals(row.id))).go();
        } else {
          await (_db.update(_db.tripExchangeRates)..where((r) => r.id.equals(row.id)))
              .write(TripExchangeRatesCompanion(rate: Value(row.rate * oldToNewRate)));
        }
      }
    });
  }
}
