import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/expense.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');
  final bob = Participant(id: 'p2', name: 'Bob');

  Expense makeExpense({ExpenseStatus status = ExpenseStatus.actual, bool includeInSplit = true}) {
    return Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(30.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 3),
      endDate: DateTime(2026, 1, 3),
      location: '',
      status: status,
      includeInSplit: includeInSplit,
      paidBy: alice,
      paidFor: [alice, bob],
    );
  }

  test('actual expense with includeInSplit=false throws', () {
    expect(
      () => makeExpense(status: ExpenseStatus.actual, includeInSplit: false),
      throwsArgumentError,
    );
  });

  test('empty paidFor throws — an expense split among zero people is meaningless, '
      'and would silently round-trip through persistence as a lookup of '
      'participant id \'\' rather than an empty list '
      '(\'\'.split(\',\') returns [\'\'], not [])', () {
    expect(
      () => Expense(
        id: 'e1',
        tripId: 't1',
        category: 'Food',
        amount: Money.fromMajor(30.00, 'EUR'),
        amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
        description: 'Dinner',
        date: DateTime(2026, 1, 3),
        endDate: DateTime(2026, 1, 3),
        location: '',
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [],
      ),
      throwsArgumentError,
    );
  });

  test('actual expense with includeInSplit=true constructs fine', () {
    final e = makeExpense(status: ExpenseStatus.actual, includeInSplit: true);
    expect(e.status, ExpenseStatus.actual);
  });

  test('planned expense can have includeInSplit=false', () {
    final e = makeExpense(status: ExpenseStatus.planned, includeInSplit: false);
    expect(e.includeInSplit, isFalse);
  });

  test('copyWith overrides only the given fields', () {
    final e = makeExpense();
    final updated = e.copyWith(description: 'Lunch instead');
    expect(updated.description, 'Lunch instead');
    expect(updated.amount, e.amount);
    expect(updated.id, e.id);
  });

  test('convertToActual flips status and forces includeInSplit true', () {
    final planned = makeExpense(status: ExpenseStatus.planned, includeInSplit: false);
    final actual = planned.convertToActual();
    expect(actual.status, ExpenseStatus.actual);
    expect(actual.includeInSplit, isTrue);
    expect(actual.amount, planned.amount); // unchanged when no override given
  });

  test('convertToActual can override the amount with the real spent amount', () {
    final planned = makeExpense(status: ExpenseStatus.planned, includeInSplit: false);
    final actual = planned.convertToActual(
      actualAmount: Money.fromMajor(35.00, 'EUR'),
      actualAmountInHomeCurrency: Money.fromMajor(35.00, 'EUR'),
    );
    expect(actual.amount, Money.fromMajor(35.00, 'EUR'));
  });

  test('an endDate before date throws — the amount always counts once, on date, so an end '
      'before the start would just be a contradiction, not a shorter span', () {
    expect(
      () => Expense(
        id: 'e1',
        tripId: 't1',
        category: 'Food',
        amount: Money.fromMajor(30.00, 'EUR'),
        amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
        description: 'Dinner',
        date: DateTime(2026, 1, 3),
        endDate: DateTime(2026, 1, 2),
        location: '',
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice],
      ),
      throwsArgumentError,
    );
  });

  test('endDate equal to date (the ordinary single-day case) constructs fine', () {
    final e = makeExpense();
    expect(e.endDate, e.date);
  });

  test('endDate after date (a multi-day expense, e.g. a hotel stay) constructs fine', () {
    final e = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Lodging',
      amount: Money.fromMajor(500.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(500.00, 'EUR'),
      description: 'Hotel',
      date: DateTime(2026, 1, 3),
      endDate: DateTime(2026, 1, 10),
      location: 'Paris',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    );
    expect(e.endDate, DateTime(2026, 1, 10));
    expect(e.location, 'Paris');
  });

  test('copyWith can override endDate and location independently', () {
    final e = makeExpense();
    final updated = e.copyWith(endDate: DateTime(2026, 1, 5), location: 'Tokyo');
    expect(updated.endDate, DateTime(2026, 1, 5));
    expect(updated.location, 'Tokyo');
    expect(updated.date, e.date, reason: 'date itself must stay untouched');
  });
}
