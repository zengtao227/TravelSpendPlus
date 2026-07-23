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
}
