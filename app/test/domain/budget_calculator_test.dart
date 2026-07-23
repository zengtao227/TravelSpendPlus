import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/budget_calculator.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');

  Trip makeTenDayTrip() => Trip(
        id: 't1',
        name: 'Japan',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
        homeCurrency: 'EUR',
        totalBudget: Money.fromMajor(1000.00, 'EUR'),
        participants: [alice],
      );

  Expense actualExpense(double amountEur, DateTime date) => Expense(
        id: 'e-${date.day}',
        tripId: 't1',
        category: 'Food',
        amount: Money.fromMajor(amountEur, 'EUR'),
        amountInHomeCurrency: Money.fromMajor(amountEur, 'EUR'),
        description: 'expense',
        date: date,
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice],
      );

  test('matches the official TravelSpend worked example exactly: '
      '10-day trip, EUR1000 budget, EUR800 spent in the first 6 days, '
      'EUR200 remaining, 4 days left => EUR50/day '
      '(verified 2026-07-23 against help.travel-spend.com directly, '
      'NOT the swapped-label numbers narrated in docs/design.md prose)', () {
    final trip = makeTenDayTrip();
    final expenses = [actualExpense(800.00, DateTime(2026, 1, 3))]; // spent within the first 6 days
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: expenses,
      asOf: DateTime(2026, 1, 7), // start of day 7: 6 days elapsed, 4 remain (7,8,9,10)
    );
    expect(daily, isNotNull);
    expect(daily!.major, closeTo(50.00, 0.01));
  });

  test('returns null once the trip has fully ended', () {
    final trip = makeTenDayTrip();
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: [],
      asOf: DateTime(2026, 1, 11), // day after the trip ends
    );
    expect(daily, isNull);
  });

  test('planned expenses count toward daily budget by default', () {
    final trip = makeTenDayTrip();
    final planned = Expense(
      id: 'e-planned',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(400.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(400.00, 'EUR'),
      description: 'hotel',
      date: DateTime(2026, 1, 9), // a future date within the trip
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice],
    );
    final expenses = [actualExpense(800.00, DateTime(2026, 1, 3)), planned];
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: expenses,
      asOf: DateTime(2026, 1, 7),
    );
    // remaining = 1000 - 800 - 400 = -200 (over budget once the planned hotel is counted)
    expect(daily!.major, closeTo(-50.00, 0.01)); // -200 / 4 days
  });

  test('includePlannedInDailyBudget=false excludes planned expenses', () {
    final trip = makeTenDayTrip();
    final planned = Expense(
      id: 'e-planned',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(400.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(400.00, 'EUR'),
      description: 'hotel',
      date: DateTime(2026, 1, 9),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice],
    );
    final expenses = [actualExpense(800.00, DateTime(2026, 1, 3)), planned];
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: expenses,
      asOf: DateTime(2026, 1, 7),
      includePlannedInDailyBudget: false,
    );
    expect(daily!.major, closeTo(50.00, 0.01)); // planned hotel excluded, same as the base example
  });

  test('summarize totals planned and actual separately', () {
    final trip = makeTenDayTrip();
    final planned = Expense(
      id: 'e-planned',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(400.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(400.00, 'EUR'),
      description: 'hotel',
      date: DateTime(2026, 1, 9),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice],
    );
    final summary = BudgetCalculator.summarize(
      trip: trip,
      expenses: [actualExpense(800.00, DateTime(2026, 1, 3)), planned],
    );
    expect(summary.actualTotal.major, closeTo(800.00, 0.01));
    expect(summary.plannedTotal.major, closeTo(400.00, 0.01));
    expect(summary.remaining.major, closeTo(-200.00, 0.01));
  });
}
