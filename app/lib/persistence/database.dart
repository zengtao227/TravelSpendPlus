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

@DriftDatabase(tables: [Trips, Participants, Expenses, TripExchangeRates])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.memory() : super(NativeDatabase.memory());

  static Future<AppDatabase> openOnDevice() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'travelspendplus.sqlite');
    return AppDatabase(NativeDatabase.createInBackground(File(filePath)));
  }

  @override
  int get schemaVersion => 3;

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
        },
      );
}
