import 'money.dart';
import 'participant.dart';

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
  // a hotel stay or a multi-day tour. Purely descriptive: the amount always
  // counts once, on [date], in every total and budget calculation — nothing
  // splits or duplicates across the days in between.
  final DateTime endDate;
  // Free-text place name (e.g. a city) — optional, defaults to ''. Lets a
  // trip spanning several cities be broken down by where money was spent,
  // not just when.
  final String location;
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
    required this.status,
    required this.includeInSplit,
    required this.paidBy,
    required this.paidFor,
  }) {
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
