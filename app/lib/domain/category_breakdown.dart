import 'money.dart';
import 'expense.dart';

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
  }) {
    final totalsByCategory = <String, Money>{};
    for (final e in expenses) {
      if (e.status == ExpenseStatus.planned && !includePlanned) continue;
      final current = totalsByCategory[e.category] ?? Money(minorUnits: 0, currencyCode: homeCurrency);
      totalsByCategory[e.category] = current + e.amountInHomeCurrency;
    }

    if (totalsByCategory.isEmpty) return [];

    final grandTotalMinorUnits =
        totalsByCategory.values.fold<int>(0, (acc, m) => acc + m.minorUnits);

    final slices = totalsByCategory.entries.map((entry) {
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
