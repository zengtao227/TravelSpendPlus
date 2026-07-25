import 'money.dart';
import 'expense.dart';

/// Which field of an expense to group slices by. `category` groups by
/// [Expense.category]; `location` groups by [Expense.location] (including
/// the empty string for expenses with no location set — callers decide how
/// to label that bucket, this file has no UI/l10n dependency).
enum BreakdownDimension { category, location }

class CategorySlice {
  final String category;
  final Money total;
  final double percentage;

  const CategorySlice({required this.category, required this.total, required this.percentage});
}

class CategoryBreakdownCalculator {
  static List<CategorySlice> breakdown({
    required List<Expense> expenses,
    required String homeCurrency,
    bool includePlanned = true,
    BreakdownDimension dimension = BreakdownDimension.category,
  }) {
    final totalsByKey = <String, Money>{};
    for (final e in expenses) {
      if (e.status == ExpenseStatus.planned && !includePlanned) continue;
      // Lets a user keep an outlier expense (e.g. a one-off big purchase)
      // out of the chart without excluding it from any other total.
      if (e.excludeFromBreakdown) continue;
      final key = dimension == BreakdownDimension.category ? e.category : e.location;
      final current = totalsByKey[key] ?? Money(minorUnits: 0, currencyCode: homeCurrency);
      totalsByKey[key] = current + e.amountInHomeCurrency;
    }

    if (totalsByKey.isEmpty) return [];

    final grandTotalMinorUnits = totalsByKey.values.fold<int>(0, (acc, m) => acc + m.minorUnits);

    final slices = totalsByKey.entries.map((entry) {
      final percentage = grandTotalMinorUnits == 0
          ? 0.0
          : (entry.value.minorUnits / grandTotalMinorUnits) * 100.0;
      return CategorySlice(category: entry.key, total: entry.value, percentage: percentage);
    }).toList();

    slices.sort((a, b) {
      final byTotal = b.total.minorUnits.compareTo(a.total.minorUnits);
      if (byTotal != 0) return byTotal;
      return a.category.compareTo(b.category); // deterministic tie-break, not left to sort-stability luck
    });
    return slices;
  }
}
