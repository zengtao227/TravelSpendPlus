import 'package:drift/drift.dart';

import '../domain/backup.dart';
import '../domain/civil_date.dart';
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
          startDate: civilDate(trip.startDate),
          endDate: civilDate(trip.endDate),
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
      startDate: civilDate(tripRow.startDate.toUtc()),
      endDate: civilDate(tripRow.endDate.toUtc()),
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
        startDate: civilDate(tripRow.startDate.toUtc()),
        endDate: civilDate(tripRow.endDate.toUtc()),
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
        startDate: Value(civilDate(trip.startDate)),
        endDate: Value(civilDate(trip.endDate)),
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
        date: civilDate(row.date.toUtc()),
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
          date: civilDate(expense.date),
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
        date: Value(civilDate(expense.date)),
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

  /// Changes a trip's home currency, converting everything already
  /// denominated in the old one using a *direct* rate to the new home
  /// currency for each currency actually in use — one currency's rate never
  /// gets derived by chaining through another (e.g. a JPY expense converts
  /// straight to CHF via the JPY->CHF rate the caller supplies, not via
  /// JPY->old-home->CHF), since manually-entered rates for different pairs
  /// aren't guaranteed transitively consistent and chaining them compounds
  /// whatever error each one carries.
  ///
  /// [directRatesToNewCurrency] must contain a "1 currency = ? newCurrency"
  /// entry for every currency actually in use in the trip other than
  /// [newCurrency] itself: the trip's current home currency, plus every
  /// currency that has an existing [TripExchangeRates] row (every non-home
  /// currency an expense can be in always has one — see
  /// `AddExpenseScreen`). `Expense.amountInHomeCurrency` and
  /// `Trip.totalBudget` are both stored as plain numbers re-labeled with
  /// whatever the trip's *current* home currency is, so simply changing
  /// the label without recomputing the numbers would silently corrupt every
  /// existing total. See docs/superpowers/specs/2026-07-24-travelspendplus-ui-design.md
  /// section 五 for why this replaced an earlier "just clear the rate
  /// table" design.
  Future<void> changeHomeCurrency({
    required String tripId,
    required String newCurrency,
    required Map<String, double> directRatesToNewCurrency,
  }) async {
    await _db.transaction(() async {
      final tripRow =
          await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingle();
      final oldCurrency = tripRow.homeCurrency;
      if (newCurrency == oldCurrency) {
        // A no-op rename would still rescale the budget/every expense by
        // whatever rate was typed in, silently corrupting every total for
        // no reason — reject it outright rather than let a same-currency
        // "change" through with an arbitrary multiplier.
        throw ArgumentError('New home currency ($newCurrency) is the same as the current one');
      }

      final rateRows = await (_db.select(_db.tripExchangeRates)
            ..where((r) => r.tripId.equals(tripId)))
          .get();
      final requiredCurrencies = {oldCurrency, ...rateRows.map((r) => r.fromCurrency)}
        ..remove(newCurrency);
      for (final currency in requiredCurrencies) {
        if (!directRatesToNewCurrency.containsKey(currency)) {
          throw ArgumentError('Missing a direct rate for $currency -> $newCurrency');
        }
      }

      final oldToNewRate = directRatesToNewCurrency[oldCurrency]!;
      final newBudgetMinorUnits = (tripRow.totalBudgetMinorUnits * oldToNewRate).round();
      await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          homeCurrency: Value(newCurrency),
          totalBudgetMinorUnits: Value(newBudgetMinorUnits),
        ),
      );

      final expenseRows =
          await (_db.select(_db.expenses)..where((e) => e.tripId.equals(tripId))).get();
      for (final row in expenseRows) {
        // An expense already in the new home currency needs no conversion
        // at all — using its own amount 1:1 avoids requiring a pointless
        // "1 newCurrency = ? newCurrency" rate from the caller.
        final newAmountInHome = row.amountCurrency == newCurrency
            ? row.amountMinorUnits
            : (row.amountMinorUnits * directRatesToNewCurrency[row.amountCurrency]!).round();
        await (_db.update(_db.expenses)..where((e) => e.id.equals(row.id))).write(
          ExpensesCompanion(amountInHomeCurrencyMinorUnits: Value(newAmountInHome)),
        );
      }

      for (final row in rateRows) {
        if (row.fromCurrency == newCurrency) {
          // This currency IS the new home currency now — a rescaled "1 X =
          // Y X" row would be self-referential nonsense, and this app has
          // no delete-a-single-rate flow to ever clean it up later, so it
          // must be deleted here rather than rescaled.
          await (_db.delete(_db.tripExchangeRates)..where((r) => r.id.equals(row.id))).go();
        } else {
          await (_db.update(_db.tripExchangeRates)..where((r) => r.id.equals(row.id))).write(
            TripExchangeRatesCompanion(
              rate: Value(directRatesToNewCurrency[row.fromCurrency]!),
            ),
          );
        }
      }

      // Preserve the ability to still record/view amounts in the *old* home
      // currency going forward — without this, the old home currency drops
      // out of the trip entirely (it was never itself a row in its own rate
      // table), and the next expense in that currency, or a switch back to
      // viewing it, would need the rate re-entered from scratch even though
      // it's exactly oldToNewRate ("1 oldCurrency = oldToNewRate newCurrency",
      // the same number just supplied for this operation).
      await setExchangeRate(
        tripId,
        ExchangeRate(fromCurrency: oldCurrency, toCurrency: newCurrency, rate: oldToNewRate),
      );
    });
  }

  /// Deletes a trip and everything under it. Foreign-key enforcement isn't
  /// turned on for this database (no `PRAGMA foreign_keys`/`beforeOpen`
  /// hook), so `.references(Trips, #id)` on the child tables is documentation
  /// only — it does not cascade. Every child table must be deleted
  /// explicitly, in one transaction, or deleting just the Trips row would
  /// leave orphaned Participants/Expenses/TripExchangeRates/TripCategories
  /// rows behind.
  Future<void> deleteTrip(String tripId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.expenses)..where((e) => e.tripId.equals(tripId))).go();
      await (_db.delete(_db.tripExchangeRates)..where((r) => r.tripId.equals(tripId))).go();
      await (_db.delete(_db.tripCategories)..where((c) => c.tripId.equals(tripId))).go();
      await (_db.delete(_db.participants)..where((p) => p.tripId.equals(tripId))).go();
      await (_db.delete(_db.trips)..where((t) => t.id.equals(tripId))).go();
    });
  }

  Future<List<String>> getCustomCategories(String tripId) async {
    final rows =
        await (_db.select(_db.tripCategories)..where((c) => c.tripId.equals(tripId))).get();
    return rows.map((row) => row.name).toList();
  }

  Future<void> addCustomCategory(String tripId, String name) async {
    final existing = await (_db.select(_db.tripCategories)
          ..where((c) => c.tripId.equals(tripId) & c.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) return; // already exists — nothing to do
    await _db.into(_db.tripCategories)
        .insert(TripCategoriesCompanion.insert(tripId: tripId, name: name));
  }

  /// Assembles every trip currently in the database (with its expenses and
  /// exchange rates) into one JSON-serializable backup. Pure data assembly —
  /// nothing here writes to disk or touches the OS share sheet; that's the
  /// UI layer's job (`ui/file_io.dart`).
  Future<Map<String, dynamic>> exportAllTripsToJson() async {
    final trips = await getAllTrips();
    final bundles = <TripBundle>[];
    for (final trip in trips) {
      bundles.add(TripBundle(
        trip: trip,
        expenses: await getExpenses(trip.id),
        exchangeRates: await getExchangeRates(trip.id),
        customCategories: await getCustomCategories(trip.id),
      ));
    }
    return backupToJson(bundles);
  }

  /// Restores every trip in [json] into the database via the same
  /// `createTrip`/`addExpense`/`setExchangeRate` calls any other code path
  /// uses — callers are responsible for only invoking this on an empty
  /// database (see the design spec: this app doesn't support merging a
  /// backup into existing data). Returns the number of trips imported, for
  /// a UI success message.
  Future<int> importAllTripsFromJson(Map<String, dynamic> json) async {
    final bundles = backupFromJson(json); // throws UnsupportedBackupVersionException if too new
    for (final bundle in bundles) {
      await createTrip(bundle.trip);
      for (final rate in bundle.exchangeRates) {
        await setExchangeRate(bundle.trip.id, rate);
      }
      for (final name in bundle.customCategories) {
        await addCustomCategory(bundle.trip.id, name);
      }
      for (final expense in bundle.expenses) {
        await addExpense(expense);
      }
    }
    return bundles.length;
  }
}
