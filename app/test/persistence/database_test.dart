import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/persistence/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and read back a trip row', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
          homeCurrency: 'EUR',
          totalBudgetMinorUnits: 100000,
        ));
    final rows = await db.select(db.trips).get();
    expect(rows.length, 1);
    expect(rows.first.name, 'Japan');
    expect(rows.first.totalBudgetMinorUnits, 100000);
  });

  test('can insert a participant referencing a trip', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
          homeCurrency: 'EUR',
          totalBudgetMinorUnits: 100000,
        ));
    await db.into(db.participants).insert(ParticipantsCompanion.insert(
          id: 'p1',
          tripId: 't1',
          name: 'Alice',
        ));
    final rows = await db.select(db.participants).get();
    expect(rows.length, 1);
    expect(rows.first.name, 'Alice');
    expect(rows.first.tripId, 't1');
  });

  test('can insert and read back an expense row', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
          homeCurrency: 'EUR',
          totalBudgetMinorUnits: 100000,
        ));
    await db.into(db.participants).insert(ParticipantsCompanion.insert(
          id: 'p1',
          tripId: 't1',
          name: 'Alice',
        ));
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e1',
          tripId: 't1',
          category: 'Food',
          amountMinorUnits: 3000,
          amountCurrency: 'EUR',
          amountInHomeCurrencyMinorUnits: 3000,
          description: 'Dinner',
          date: DateTime(2026, 1, 2),
          status: 'actual',
          includeInSplit: true,
          paidById: 'p1',
          paidForIds: 'p1',
        ));
    final rows = await db.select(db.expenses).get();
    expect(rows.length, 1);
    expect(rows.first.category, 'Food');
    expect(rows.first.amountMinorUnits, 3000);
    expect(rows.first.status, 'actual');
  });

  test('schema v2 has a queryable tripExchangeRates table', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 10, 5),
          endDate: DateTime(2026, 10, 12),
          homeCurrency: 'CNY',
          totalBudgetMinorUnits: 2000000,
        ));
    await db.into(db.tripExchangeRates).insert(TripExchangeRatesCompanion.insert(
          tripId: 't1',
          fromCurrency: 'JPY',
          rate: 0.05,
        ));
    final rows = await (db.select(db.tripExchangeRates)
          ..where((r) => r.tripId.equals('t1')))
        .get();
    expect(rows.length, 1);
    expect(rows.first.fromCurrency, 'JPY');
    expect(rows.first.rate, 0.05);
  });

  test('a trip cannot have two exchange rate rows for the same currency', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 10, 5),
          endDate: DateTime(2026, 10, 12),
          homeCurrency: 'CNY',
          totalBudgetMinorUnits: 2000000,
        ));
    await db.into(db.tripExchangeRates).insert(TripExchangeRatesCompanion.insert(
          tripId: 't1',
          fromCurrency: 'JPY',
          rate: 0.05,
        ));
    // A second row for the same (tripId, fromCurrency) pair, bypassing
    // TripRepository.setExchangeRate's own application-level check, must
    // still be rejected by the schema's unique constraint.
    await expectLater(
      db.into(db.tripExchangeRates).insert(TripExchangeRatesCompanion.insert(
            tripId: 't1',
            fromCurrency: 'JPY',
            rate: 0.06,
          )),
      throwsA(isA<Exception>()),
    );
  });

  test('upgrades an existing v6 expense row with safe v7 defaults', () async {
    // This test opens the same file twice in sequence to exercise a real
    // schema upgrade, so release the in-memory database created by setUp.
    await db.close();
    final tempDir = await Directory.systemTemp.createTemp('v6_migration_test');
    final file = File('${tempDir.path}/travelspendplus.sqlite');
    AppDatabase? legacy;
    AppDatabase? upgraded;
    try {
      legacy = AppDatabase(NativeDatabase(file, enableMigrations: false));
      await legacy.customStatement('''
      CREATE TABLE expenses (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL,
        category TEXT NOT NULL,
        amount_minor_units INTEGER NOT NULL,
        amount_currency TEXT NOT NULL,
        amount_in_home_currency_minor_units INTEGER NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        end_date INTEGER,
        location TEXT NOT NULL DEFAULT '',
        exclude_from_breakdown INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        include_in_split INTEGER NOT NULL,
        paid_by_id TEXT NOT NULL,
        paid_for_ids TEXT NOT NULL
      )
    ''');
      // TripCategories was introduced in schema v4, so a real v6 database
      // already has this table even when it contains no custom categories.
      await legacy.customStatement('''
      CREATE TABLE trip_categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL,
        name TEXT NOT NULL,
        UNIQUE (trip_id, name)
      )
    ''');
      await legacy.customStatement('''
      INSERT INTO expenses VALUES (
        'e-v6', 't1', 'food', 3000, 'EUR', 3000, 'Dinner',
        1767312000, 1767312000, '', 0, 'actual', 1, 'p1', 'p1'
      )
    ''');
      await legacy.customStatement('''
      INSERT INTO expenses VALUES (
        'e-range', 't1', 'accommodation', 10001, 'EUR', 10001, 'Hotel',
        1767312000, 1767484800, 'Kyoto', 0, 'actual', 1, 'p1', 'p1'
      )
    ''');
      await legacy.customStatement('''
      INSERT INTO expenses VALUES (
        'e-no-end', 't1', 'food', 1000, 'EUR', 1000, 'Coffee',
        1767312000, NULL, '', 0, 'actual', 1, 'p1', 'p1'
      )
    ''');
      await legacy.customStatement('PRAGMA user_version = 6');
      await legacy.close();
      legacy = null;

      upgraded = AppDatabase(NativeDatabase(file));
      final row = await (upgraded.select(
        upgraded.expenses,
      )..where((e) => e.id.equals('e-v6'))).getSingle();
      final userVersion = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(row.amountMinorUnits, 3000);
      expect(row.date.toUtc(), DateTime.utc(2026, 1, 2));
      expect(row.status, 'actual');
      expect(row.spreadAcrossDays, isFalse);
      expect(row.createdAt, 0);
      final range = await (upgraded.select(upgraded.expenses)
            ..where((e) => e.id.equals('e-range'))).getSingle();
      final noEnd = await (upgraded.select(upgraded.expenses)
            ..where((e) => e.id.equals('e-no-end'))).getSingle();
      expect(range.spreadAcrossDays, true);
      expect(range.amountMinorUnits, 10001);
      expect(range.endDate!.toUtc(), DateTime.utc(2026, 1, 4));
      expect(noEnd.spreadAcrossDays, false);

      expect(userVersion.read<int>('user_version'), 9);
    } finally {
      await upgraded?.close();
      await legacy?.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('upgrades v7 category rows and expenses to the current schema without losing data', () async {
    await db.close();
    final tempDir = await Directory.systemTemp.createTemp('v7_category_migration_test');
    final file = File('${tempDir.path}/travelspendplus.sqlite');
    AppDatabase? legacy;
    AppDatabase? upgraded;
    try {
      legacy = AppDatabase(NativeDatabase(file, enableMigrations: false));
      await legacy.customStatement('''
        CREATE TABLE trip_categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          trip_id TEXT NOT NULL,
          name TEXT NOT NULL,
          UNIQUE (trip_id, name)
        )
      ''');
      await legacy.customStatement("INSERT INTO trip_categories (trip_id, name) VALUES ('t1', 'Souvenirs')");
      await legacy.customStatement('''
        CREATE TABLE expenses (
          id TEXT NOT NULL PRIMARY KEY,
          trip_id TEXT NOT NULL,
          category TEXT NOT NULL,
          amount_minor_units INTEGER NOT NULL,
          amount_currency TEXT NOT NULL,
          amount_in_home_currency_minor_units INTEGER NOT NULL,
          description TEXT NOT NULL,
          date INTEGER NOT NULL,
          end_date INTEGER,
          location TEXT NOT NULL DEFAULT '',
          exclude_from_breakdown INTEGER NOT NULL DEFAULT 0,
          spread_across_days INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL,
          include_in_split INTEGER NOT NULL,
          paid_by_id TEXT NOT NULL,
          paid_for_ids TEXT NOT NULL
        )
      ''');
      await legacy.customStatement("INSERT INTO expenses VALUES ('e1', 't1', 'Souvenirs', 4200, 'EUR', 4200, 'Gift', 1767312000, 1767312000, '', 0, 0, 7, 'actual', 1, 'p1', 'p1')");
      await legacy.customStatement('PRAGMA user_version = 7');
      await legacy.close();
      legacy = null;

      upgraded = AppDatabase(NativeDatabase(file));
      final category = (await upgraded.select(upgraded.tripCategories).get()).single;
      final expense = (await upgraded.select(upgraded.expenses).get()).single;
      final userVersion = await upgraded.customSelect('PRAGMA user_version').getSingle();

      expect(category.name, 'Souvenirs');
      expect(category.displayName, isNull);
      expect(category.iconKey, isNull);
      expect(category.hidden, isFalse);
      expect(expense.category, 'Souvenirs');
      expect(expense.amountMinorUnits, 4200);
      expect(userVersion.read<int>('user_version'), 9);
    } finally {
      await upgraded?.close();
      await legacy?.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('upgrades v8 expenses to schema v9 without changing existing records', () async {
    await db.close();
    final tempDir = await Directory.systemTemp.createTemp('v8_rental_migration_test');
    final file = File('${tempDir.path}/travelspendplus.sqlite');
    AppDatabase? legacy;
    AppDatabase? upgraded;
    try {
      legacy = AppDatabase(NativeDatabase(file, enableMigrations: false));
      await legacy.customStatement('''
        CREATE TABLE expenses (
          id TEXT NOT NULL PRIMARY KEY,
          trip_id TEXT NOT NULL,
          category TEXT NOT NULL,
          amount_minor_units INTEGER NOT NULL,
          amount_currency TEXT NOT NULL,
          amount_in_home_currency_minor_units INTEGER NOT NULL,
          description TEXT NOT NULL,
          date INTEGER NOT NULL,
          end_date INTEGER,
          location TEXT NOT NULL DEFAULT '',
          exclude_from_breakdown INTEGER NOT NULL DEFAULT 0,
          spread_across_days INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL,
          include_in_split INTEGER NOT NULL,
          paid_by_id TEXT NOT NULL,
          paid_for_ids TEXT NOT NULL
        )
      ''');
      await legacy.customStatement("INSERT INTO expenses VALUES ('e1', 't1', 'transport', 4200, 'EUR', 4200, 'Car rental', 1767312000, 1767398400, '', 0, 1, 7, 'actual', 1, 'p1', 'p1')");
      await legacy.customStatement('PRAGMA user_version = 8');
      await legacy.close();
      legacy = null;

      upgraded = AppDatabase(NativeDatabase(file));
      final expense = (await upgraded.select(upgraded.expenses).get()).single;
      final userVersion = await upgraded.customSelect('PRAGMA user_version').getSingle();

      expect(expense.id, 'e1');
      expect(expense.category, 'transport');
      expect(expense.amountMinorUnits, 4200);
      expect(expense.endDate!.toUtc(), DateTime.utc(2026, 1, 3));
      expect(expense.rentalPickupMinutes, isNull);
      expect(expense.rentalReturnMinutes, isNull);
      expect(userVersion.read<int>('user_version'), 9);
    } finally {
      await upgraded?.close();
      await legacy?.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });
}
