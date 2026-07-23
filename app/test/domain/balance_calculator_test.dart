import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/balance_calculator.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');
  final bob = Participant(id: 'p2', name: 'Bob');
  final carol = Participant(id: 'p3', name: 'Carol');

  test('worked 3-person example: Alice pays 90 split 3 ways, '
      'Bob pays 60 split with Alice only => Alice +30, Bob 0, Carol -30', () {
    final expense1 = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(90.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(90.00, 'EUR'),
      description: 'Dinner for 3',
      date: DateTime(2026, 1, 2),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice, bob, carol],
    );
    final expense2 = Expense(
      id: 'e2',
      tripId: 't1',
      category: 'Transport',
      amount: Money.fromMajor(60.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(60.00, 'EUR'),
      description: 'Taxi for 2',
      date: DateTime(2026, 1, 3),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: bob,
      paidFor: [alice, bob],
    );

    final balances = BalanceCalculator.netBalances(
      expenses: [expense1, expense2],
      homeCurrency: 'EUR',
    );

    expect(balances[alice]!.major, closeTo(30.00, 0.01));
    expect(balances[bob]!.major, closeTo(0.00, 0.01));
    expect(balances[carol]!.major, closeTo(-30.00, 0.01));

    final sum = balances.values.fold<int>(0, (acc, m) => acc + m.minorUnits);
    expect(sum, 0, reason: 'net balances must always sum to zero');
  });

  test('planned expense with includeInSplit=false is excluded from balances', () {
    final planned = Expense(
      id: 'e3',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(200.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(200.00, 'EUR'),
      description: 'Hotel deposit',
      date: DateTime(2026, 1, 5),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    final balances = BalanceCalculator.netBalances(expenses: [planned], homeCurrency: 'EUR');
    // A participant who appears only in split-excluded expenses gets no map
    // entry at all (consistent with the "no expenses => empty map" test
    // below) — not a zero-value entry. Checking balances[alice]!  here
    // would throw a null-check error, since alice/bob were never inserted.
    expect(balances.containsKey(alice), isFalse);
    expect(balances.containsKey(bob), isFalse);
  });

  test('planned expense with includeInSplit=true is included in balances', () {
    final planned = Expense(
      id: 'e4',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(200.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(200.00, 'EUR'),
      description: 'Hotel deposit',
      date: DateTime(2026, 1, 5),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    final balances = BalanceCalculator.netBalances(expenses: [planned], homeCurrency: 'EUR');
    expect(balances[alice]!.major, closeTo(100.00, 0.01));
    expect(balances[bob]!.major, closeTo(-100.00, 0.01));
  });

  test('with no expenses, all known participants are absent (empty map)', () {
    final balances = BalanceCalculator.netBalances(expenses: [], homeCurrency: 'EUR');
    expect(balances, isEmpty);
  });
}
