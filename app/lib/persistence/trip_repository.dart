import 'package:drift/drift.dart';

import '../domain/money.dart';
import '../domain/participant.dart';
import '../domain/trip.dart';
import '../domain/expense.dart';
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
      final paidFor = row.paidForIds.split(',').map((id) => participantsById[id]!).toList();
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
}
