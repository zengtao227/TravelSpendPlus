import 'money.dart';
import 'participant.dart';
import 'expense.dart';

class BalanceCalculator {
  /// Net balance per participant across all expenses that count toward the
  /// split ledger (actual expenses always do; planned expenses only when
  /// `includeInSplit` is true — see Expense's own invariant). Positive means
  /// the participant should receive money; negative means they owe it.
  /// Balances always sum to zero.
  static Map<Participant, Money> netBalances({
    required List<Expense> expenses,
    required String homeCurrency,
  }) {
    final balances = <Participant, Money>{};

    Money zero() => Money(minorUnits: 0, currencyCode: homeCurrency);
    Money current(Participant p) => balances[p] ?? zero();

    for (final expense in expenses) {
      if (!expense.includeInSplit) continue;

      balances[expense.paidBy] = current(expense.paidBy) + expense.amountInHomeCurrency;

      final shares = splitEvenly(expense.amountInHomeCurrency, expense.paidFor.length);
      for (var i = 0; i < expense.paidFor.length; i++) {
        final person = expense.paidFor[i];
        balances[person] = current(person) - shares[i];
      }
    }

    return balances;
  }
}
