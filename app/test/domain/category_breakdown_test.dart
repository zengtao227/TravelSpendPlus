import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/category_breakdown.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');

  Expense makeExpense(
    String category,
    double amount, {
    ExpenseStatus status = ExpenseStatus.actual,
    String location = '',
    bool excludeFromBreakdown = false,
  }) {
    return Expense(
      id: '$category-$amount-${location.hashCode}',
      tripId: 't1',
      category: category,
      amount: Money.fromMajor(amount, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(amount, 'EUR'),
      description: category,
      date: DateTime(2026, 1, 2),
      endDate: DateTime(2026, 1, 2),
      location: location,
      excludeFromBreakdown: excludeFromBreakdown,
      status: status,
      includeInSplit: status == ExpenseStatus.actual,
      paidBy: alice,
      paidFor: [alice],
    );
  }

  test('groups by category, sums amounts, computes percentages, '
      'and breaks a tie alphabetically (not left to List.sort\'s '
      'unspecified tie-break order)', () {
    final expenses = [
      makeExpense('Food', 60.00),
      makeExpense('Food', 40.00),
      makeExpense('Transport', 100.00),
    ];
    final slices = CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: 'EUR');

    expect(slices.length, 2);
    // Food (60+40=100) and Transport (100) tie exactly — alphabetically
    // 'Food' < 'Transport', so Food sorts first.
    expect(slices[0].category, 'Food');
    expect(slices[0].total.major, closeTo(100.00, 0.01));
    expect(slices[0].percentage, closeTo(50.0, 0.1));
    expect(slices[1].category, 'Transport');
    expect(slices[1].total.major, closeTo(100.00, 0.01));
    expect(slices[1].percentage, closeTo(50.0, 0.1));
  });

  test('unambiguous sort order when totals differ', () {
    final expenses = [makeExpense('Food', 20.00), makeExpense('Transport', 80.00)];
    final slices = CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: 'EUR');
    expect(slices[0].category, 'Transport');
    expect(slices[0].percentage, closeTo(80.0, 0.1));
    expect(slices[1].category, 'Food');
    expect(slices[1].percentage, closeTo(20.0, 0.1));
  });

  test('includePlanned=false excludes planned expenses', () {
    final expenses = [
      makeExpense('Food', 50.00, status: ExpenseStatus.actual),
      makeExpense('Hotel', 200.00, status: ExpenseStatus.planned),
    ];
    final slices = CategoryBreakdownCalculator.breakdown(
      expenses: expenses,
      homeCurrency: 'EUR',
      includePlanned: false,
    );
    expect(slices.length, 1);
    expect(slices[0].category, 'Food');
    expect(slices[0].percentage, closeTo(100.0, 0.1));
  });

  test('empty expense list returns empty breakdown', () {
    final slices = CategoryBreakdownCalculator.breakdown(expenses: [], homeCurrency: 'EUR');
    expect(slices, isEmpty);
  });

  test('dimension=location groups by location instead of category, '
      'including an empty-string bucket for expenses with no location set', () {
    final expenses = [
      makeExpense('Food', 30.00, location: 'Paris'),
      makeExpense('Transport', 20.00, location: 'Paris'),
      makeExpense('Food', 50.00, location: 'Tokyo'),
      makeExpense('Other', 10.00, location: ''),
    ];
    final slices = CategoryBreakdownCalculator.breakdown(
      expenses: expenses,
      homeCurrency: 'EUR',
      dimension: BreakdownDimension.location,
    );
    expect(slices.length, 3);
    expect(slices[0].category, 'Paris');
    expect(slices[0].total.major, closeTo(50.00, 0.01));
    expect(slices[1].category, 'Tokyo');
    expect(slices[1].total.major, closeTo(50.00, 0.01));
    expect(slices[2].category, '');
    expect(slices[2].total.major, closeTo(10.00, 0.01));
  });

  test('excludeFromBreakdown=true skips an expense entirely, '
      'whichever dimension is used', () {
    final expenses = [
      makeExpense('Food', 50.00),
      makeExpense('Shopping', 500.00, excludeFromBreakdown: true),
    ];
    final slices = CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: 'EUR');
    expect(slices.length, 1);
    expect(slices[0].category, 'Food');
    expect(slices[0].percentage, closeTo(100.0, 0.1));
  });
}
