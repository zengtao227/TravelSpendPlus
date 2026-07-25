import 'civil_date.dart';
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
    // Normalized to UTC-midnight civil dates (see civil_date.dart) so this
    // arithmetic is exact across a DST transition and independent of
    // whatever timezone `asOf`/`trip.endDate`/each expense date happen to
    // carry — none of these DateTimes are guaranteed pre-normalized (tests
    // construct plain local ones directly), so this function normalizes
    // defensively rather than trusting callers.
    final startOfAsOfDay = civilDate(asOf);
    final daysLeft = civilDate(trip.endDate).difference(startOfAsOfDay).inDays + 1;
    if (daysLeft <= 0) return null;

    Money usedSoFar = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    for (final e in expenses) {
      // Compare by calendar day, not by instant — expense dates carry a time
      // component (e.g. AddExpenseScreen defaults to DateTime.now()), so a
      // raw isBefore/isAfter against midnight would wrongly include today's
      // own actual spending (created earlier today) or exclude an actual
      // expense recorded exactly at midnight.
      final expenseDay = civilDate(e.date);
      final isActualNotToday =
          e.status == ExpenseStatus.actual && expenseDay != startOfAsOfDay;
      final isCountedPlanned = e.status == ExpenseStatus.planned && includePlannedInDailyBudget;
      if (isActualNotToday || isCountedPlanned) {
        usedSoFar = usedSoFar + e.amountInHomeCurrency;
      }
    }

    final remainingAtStartOfToday = trip.totalBudget - usedSoFar;
    return remainingAtStartOfToday.dividedBy(daysLeft);
  }
}
