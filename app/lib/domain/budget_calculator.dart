import 'money.dart';
import 'trip.dart';
import 'expense.dart';

class BudgetSummary {
  final Money totalBudget;
  final Money plannedTotal;
  final Money actualTotal;
  final Money remaining;

  const BudgetSummary({
    required this.totalBudget,
    required this.plannedTotal,
    required this.actualTotal,
    required this.remaining,
  });
}

class BudgetCalculator {
  static BudgetSummary summarize({required Trip trip, required List<Expense> expenses}) {
    Money planned = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    Money actual = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    for (final e in expenses) {
      if (e.status == ExpenseStatus.planned) {
        planned = planned + e.amountInHomeCurrency;
      } else {
        actual = actual + e.amountInHomeCurrency;
      }
    }
    return BudgetSummary(
      totalBudget: trip.totalBudget,
      plannedTotal: planned,
      actualTotal: actual,
      remaining: trip.totalBudget - planned - actual,
    );
  }

  /// "What was left of the total budget at the start of [asOf]'s day,
  /// divided by the number of days left" — TravelSpend's own definition.
  /// Only actual expenses dated *before* [asOf]'s day reduce the "at start
  /// of today" remaining amount (today's own actual spending hasn't
  /// happened yet at the moment you check this each morning); planned
  /// expenses count regardless of date when [includePlannedInDailyBudget]
  /// is true, since committed future spending is treated as already
  /// accounted for (docs/design.md section 2).
  static Money? remainingDailyBudget({
    required Trip trip,
    required List<Expense> expenses,
    required DateTime asOf,
    bool includePlannedInDailyBudget = true,
  }) {
    final startOfAsOfDay = DateTime(asOf.year, asOf.month, asOf.day);
    final daysLeft = trip.endDate.difference(startOfAsOfDay).inDays + 1;
    if (daysLeft <= 0) return null;

    Money usedSoFar = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    for (final e in expenses) {
      final isActualBeforeToday =
          e.status == ExpenseStatus.actual && e.date.isBefore(startOfAsOfDay);
      final isCountedPlanned = e.status == ExpenseStatus.planned && includePlannedInDailyBudget;
      if (isActualBeforeToday || isCountedPlanned) {
        usedSoFar = usedSoFar + e.amountInHomeCurrency;
      }
    }

    final remainingAtStartOfToday = trip.totalBudget - usedSoFar;
    return remainingAtStartOfToday.dividedBy(daysLeft);
  }
}
