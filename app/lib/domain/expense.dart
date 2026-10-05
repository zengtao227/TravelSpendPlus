import 'money.dart';
import 'participant.dart';
import 'civil_date.dart';

enum ExpenseStatus { planned, actual }

/// A single trip expense — either [ExpenseStatus.planned] (booked/estimated,
/// hasn't happened yet) or [ExpenseStatus.actual] (money already spent).
///
/// Actual expenses always count toward the split ledger (you can't un-split
/// money that's already been spent), so [includeInSplit] must be `true` when
/// [status] is [ExpenseStatus.actual]; for planned expenses it's the user's
/// choice (docs/design.md section 2, confirmed 2026-07-17).
class Expense {
  final String id;
  final String tripId;
  final String category;
  final Money amount;
  final Money amountInHomeCurrency;
  final String description;
  final DateTime date;
  // The last day this expense covers — same as [date] for an ordinary
  // single-day expense (e.g. dinner), later than [date] for something like
  // a hotel stay or a multi-day tour. Amounts are always allocated evenly
  // across this inclusive range.
  final DateTime endDate;
  // Free-text place name (e.g. a city) — optional, defaults to ''. Lets a
  // trip spanning several cities be broken down by where money was spent,
  // not just when.
  final String location;
  // When true, this expense is skipped by CategoryBreakdownCalculator (the
  // pie chart on the trip detail screen) — e.g. a one-off big-ticket item
  // (a car, a laptop) the user doesn't want skewing the category/location
  // split. It still counts toward every other total (budget, split ledger).
  final bool excludeFromBreakdown;
  bool get spreadAcrossDays => civilDate(endDate).isAfter(civilDate(date));

  int get coveredDays => civilDate(endDate).difference(civilDate(date)).inDays + 1;

  /// Creation instant retained across edits so same-day entries can be
  /// displayed newest first. Kept at microsecond precision in persistence.
  final DateTime createdAt;
  final ExpenseStatus status;
  final bool includeInSplit;
  final Participant paidBy;
  final List<Participant> paidFor;

  Expense({
    required this.id,
    required this.tripId,
    required this.category,
    required this.amount,
    required this.amountInHomeCurrency,
    required this.description,
    required this.date,
    required this.endDate,
    required this.location,
    this.excludeFromBreakdown = false,
    DateTime? createdAt,
    required this.status,
    required this.includeInSplit,
    required this.paidBy,
    required this.paidFor,
  }) : createdAt = (createdAt ?? DateTime.now()).toUtc() {
    if (status == ExpenseStatus.actual && !includeInSplit) {
      throw ArgumentError('Actual expenses must have includeInSplit = true');
    }
    if (paidFor.isEmpty) {
      // An expense split among zero people is meaningless, and the
      // persistence layer joins paidFor's ids with ',' — an empty list
      // joins to '', and ''.split(',') in Dart returns [''] (one empty
      // string), not [] (confirmed empirically: 'x'.split(',').length
      // for x='' is 1, not 0). That would crash TripRepository.getExpenses
      // on the round trip with a null-check error looking up participant
      // id ''. Reject it here instead of letting it round-trip into a crash.
      throw ArgumentError('paidFor must not be empty');
    }
    if (endDate.isBefore(date)) {
      throw ArgumentError('endDate must not be before date');
    }
  }

  Expense copyWith({
    String? id,
    String? tripId,
    String? category,
    Money? amount,
    Money? amountInHomeCurrency,
    String? description,
    DateTime? date,
    DateTime? endDate,
    String? location,
    bool? excludeFromBreakdown,
    DateTime? createdAt,
    ExpenseStatus? status,
    bool? includeInSplit,
    Participant? paidBy,
    List<Participant>? paidFor,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      amountInHomeCurrency: amountInHomeCurrency ?? this.amountInHomeCurrency,
      description: description ?? this.description,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      excludeFromBreakdown: excludeFromBreakdown ?? this.excludeFromBreakdown,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      includeInSplit: includeInSplit ?? this.includeInSplit,
      paidBy: paidBy ?? this.paidBy,
      paidFor: paidFor ?? this.paidFor,
    );
  }

  /// Marks a planned expense as actually spent. If the real amount differed
  /// from the estimate, pass [actualAmount]/[actualAmountInHomeCurrency] to
  /// update it in the same step — estimate and actual are not forced equal.
  Expense convertToActual({Money? actualAmount, Money? actualAmountInHomeCurrency}) {
    return copyWith(
      status: ExpenseStatus.actual,
      includeInSplit: true,
      amount: actualAmount,
      amountInHomeCurrency: actualAmountInHomeCurrency,
    );
  }
}

/// One expense amount allocated to one calendar day. It keeps the source
/// expense so callers can group, edit, or open the original record without
/// creating duplicated persisted expenses.
class DailyExpenseAllocation {
  final Expense expense;
  final DateTime date;
  final Money amount;
  final Money amountInHomeCurrency;

  const DailyExpenseAllocation({
    required this.expense,
    required this.date,
    required this.amount,
    required this.amountInHomeCurrency,
  });
}

/// Allocates [expense] onto its displayed calendar days. Ordinary expenses
/// remain a single entry on [Expense.date]; every multi-day expense is
/// split inclusively from [Expense.date] to [Expense.endDate]. [splitEvenly]
/// assigns any remainder cents to earliest days, so each currency sums back
/// to the source expense exactly.
List<DailyExpenseAllocation> dailyExpenseAllocations(Expense expense) {
  final start = civilDate(expense.date);
  if (!expense.spreadAcrossDays) {
    return [
      DailyExpenseAllocation(
        expense: expense,
        date: start,
        amount: expense.amount,
        amountInHomeCurrency: expense.amountInHomeCurrency,
      ),
    ];
  }

  final end = civilDate(expense.endDate);
  final days = end.difference(start).inDays + 1;
  final amounts = _dailyShares(expense.amount, days);
  final homeAmounts = _dailyShares(expense.amountInHomeCurrency, days);
  return List.generate(days, (index) {
    return DailyExpenseAllocation(
      expense: expense,
      date: start.add(Duration(days: index)),
      amount: amounts[index],
      amountInHomeCurrency: homeAmounts[index],
    );
  });
}

List<Money> _dailyShares(Money amount, int days) {
  if (amount.minorUnits >= 0) return splitEvenly(amount, days);
  // Backups can contain refunds; split their magnitude before restoring the
  // sign so remainder cents still sum to the original negative amount.
  return splitEvenly(-amount, days).map((share) => -share).toList();
}
