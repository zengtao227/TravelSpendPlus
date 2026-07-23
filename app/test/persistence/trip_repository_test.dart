import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/expense.dart';
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
}
