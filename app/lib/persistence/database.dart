import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get homeCurrency => text()();
  IntColumn get totalBudgetMinorUnits => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Participants extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// [paidForIds] is a comma-separated list of participant IDs — a deliberate
/// MVP simplification instead of a many-to-many join table. See this
/// plan's Task 8 notes.
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get category => text()();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get amountCurrency => text()();
  IntColumn get amountInHomeCurrencyMinorUnits => integer()();
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  // Nullable purely for pre-migration rows: every row this app writes
  // itself always has a concrete value (defaulting to [date] for an
  // ordinary single-day expense) — see TripRepository.getExpenses, which
  // falls back to [date] when this is null.
  DateTimeColumn get endDate => dateTime().nullable()();
  // Local wall-clock minutes on the selected civil dates for a car rental.
  // Both values are null for ordinary/calendar-day expenses. They remain
  // nullable so existing records retain their established allocation rule.
  IntColumn get rentalPickupMinutes => integer().nullable()();
  IntColumn get rentalReturnMinutes => integer().nullable()();
  TextColumn get location => text().withDefault(const Constant(''))();
  BoolColumn get excludeFromBreakdown => boolean().withDefault(const Constant(false))();
  BoolColumn get spreadAcrossDays =>
      boolean().withDefault(const Constant(false))();
  // DateTime columns use second-resolution storage in this SQLite setup.
  // Creation order needs finer precision, so retain UTC epoch microseconds
  // explicitly. A zero default marks a pre-v7 row whose order falls back to
  // SQLite's insertion rowid in TripRepository.
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  TextColumn get status => text()(); // 'planned' | 'actual'
  BoolColumn get includeInSplit => boolean()();
  TextColumn get paidById => text().references(Participants, #id)();
  TextColumn get paidForIds => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A trip's manually maintained "1 fromCurrency = rate homeCurrency" list
/// (see `CurrencyConverter`). `toCurrency` isn't stored — it's always the
/// owning trip's current `homeCurrency`, looked up via `tripId` when read.
class TripExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get fromCurrency => text()();
  RealColumn get rate => real()();

  // Enforced at the schema level, not just by TripRepository.setExchangeRate's
  // check-then-write logic: a trip must never have two rate rows for the
  // same currency. That repository method already prevents duplicates on
  // its own write path, but a schema-level unique constraint is the actual
  // guarantee against any other path ever creating one.
  @override
  List<Set<Column>> get uniqueKeys => [
        {tripId, fromCurrency},
      ];
}

/// Custom category keys and per-trip overrides for built-in categories.
/// Names remain stable so presentation changes never rewrite old expenses.
class TripCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tripId => text().references(Trips, #id)();
  // Immutable expense/category key. For legacy custom categories this is the
  // user-entered name; presentation fields below can now change independently.
  TextColumn get name => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {tripId, name},
      ];
}

@DriftDatabase(tables: [Trips, Participants, Expenses, TripExchangeRates, TripCategories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.memory() : super(NativeDatabase.memory());

  static Future<AppDatabase> openOnDevice() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'travelspendplus.sqlite');
    return AppDatabase(NativeDatabase.createInBackground(File(filePath)));
  }

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(tripExchangeRates);
          }
          if (from < 3) {
            // v2's tripExchangeRates table had no unique constraint on
            // (tripId, fromCurrency) — add it directly via SQL, since Drift's
            // MigrationStrategy has no "add a unique index to an existing
            // table" helper beyond raw statements.
            await m.database.customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS trip_exchange_rates_trip_currency_unique '
              'ON trip_exchange_rates (trip_id, from_currency)',
            );
          }
          if (from < 4) {
            await m.createTable(tripCategories);
          }
          if (from < 5) {
            await m.addColumn(expenses, expenses.endDate);
            await m.addColumn(expenses, expenses.location);
          }
          if (from < 6) {
            await m.addColumn(expenses, expenses.excludeFromBreakdown);
          }
          if (from < 7) {
            await m.addColumn(expenses, expenses.spreadAcrossDays);
            await m.addColumn(expenses, expenses.createdAt);
            // Existing date ranges represent costs covering multiple days.
            // Preserve source rows and amounts; only enable their daily view.
            await m.database.customStatement(
              'UPDATE expenses SET spread_across_days = 1 WHERE end_date > date',
            );
          }
          // Databases before v4 create TripCategories here from the current
          // table definition, which already has these three fields. Existing
          // v4-v7 tables need only the additive migration below.
          if (from >= 4 && from < 8) {
            await m.addColumn(tripCategories, tripCategories.displayName);
            await m.addColumn(tripCategories, tripCategories.iconKey);
            await m.addColumn(tripCategories, tripCategories.hidden);
          }
          if (from < 9) {
            await m.addColumn(expenses, expenses.rentalPickupMinutes);
            await m.addColumn(expenses, expenses.rentalReturnMinutes);
          }
        },
      );
}
