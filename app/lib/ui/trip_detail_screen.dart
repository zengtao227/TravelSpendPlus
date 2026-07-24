// app/lib/ui/trip_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/budget_calculator.dart';
import '../domain/category_breakdown.dart';
import '../domain/currency_converter.dart';
import '../domain/exchange_rate.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/money.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'add_expense_screen.dart';
import 'create_trip_screen.dart';
import 'exchange_rate_settings_screen.dart';
import 'formatting.dart';
import 'theme.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final TripRepository repository;
  const TripDetailScreen({super.key, required this.tripId, required this.repository});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailData {
  final Trip trip;
  final List<Expense> expenses;
  final List<ExchangeRate> rates;
  _TripDetailData(this.trip, this.expenses, this.rates);
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<_TripDetailData> _future;
  String? _viewCurrency; // null = show in home currency

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TripDetailData> _load() async {
    final trip = await widget.repository.getTrip(widget.tripId);
    final expenses = await widget.repository.getExpenses(widget.tripId);
    final rates = await widget.repository.getExchangeRates(widget.tripId);
    return _TripDetailData(trip!, expenses, rates);
  }

  // Resets _viewCurrency too, not just _future: if the trip's home currency
  // was changed (via ExchangeRateSettingsScreen) while a non-default
  // _viewCurrency was selected, that currency may no longer have a rate
  // entry relative to the *new* home currency, and CurrencyConverter.convert
  // throws in that case. Matches the design spec's own rule that the
  // currency switch is view-only and resets on navigating away.
  void _refresh() => setState(() {
        _future = _load();
        _viewCurrency = null;
      });

  Future<void> _markAsSpent(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: expense.amount.major.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.markAsSpent),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.markAsSpentPrompt),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    final enteredText = controller.text;
    controller.dispose();
    if (confirmed != true) return;
    final newAmountMajor = double.tryParse(enteredText) ?? expense.amount.major;
    final newAmount = Money.fromMajor(newAmountMajor, expense.amount.currencyCode);
    final ratio = expense.amount.minorUnits == 0
        ? 1.0
        : newAmount.minorUnits / expense.amount.minorUnits;
    final newAmountInHome = Money(
      minorUnits: (expense.amountInHomeCurrency.minorUnits * ratio).round(),
      currencyCode: expense.amountInHomeCurrency.currencyCode,
    );
    await widget.repository.updateExpense(expense.convertToActual(
      actualAmount: newAmount,
      actualAmountInHomeCurrency: newAmountInHome,
    ));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          FutureBuilder<_TripDetailData>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final trip = snapshot.data!.trip;
              return Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CreateTripScreen(repository: widget.repository, existingTrip: trip),
                    ));
                    _refresh();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.currency_exchange),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExchangeRateSettingsScreen(trip: trip, repository: widget.repository),
                    ));
                    _refresh();
                  },
                ),
              ]);
            },
          ),
        ],
      ),
      body: FutureBuilder<_TripDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final trip = data.trip;
          final expenses = data.expenses;
          final summary = BudgetCalculator.summarize(trip: trip, expenses: expenses);
          final breakdown =
              CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: trip.homeCurrency);
          final displayCurrency = _viewCurrency ?? trip.homeCurrency;

          Money display(Money amount) => displayCurrency == amount.currencyCode
              ? amount
              : CurrencyConverter.convert(
                  amount: amount,
                  toCurrency: displayCurrency,
                  rates: data.rates,
                  homeCurrency: trip.homeCurrency,
                );

          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          Widget budgetTimingWidget;
          if (now.isBefore(trip.startDate)) {
            final days = trip.startDate.difference(startOfToday).inDays;
            budgetTimingWidget = Chip(label: Text(l10n.daysUntilDeparture(days)));
          } else if (startOfToday.isAfter(trip.endDate)) {
            // Compare the start of *today* (not the current instant) against
            // endDate: endDate is stored at midnight, so comparing `now`
            // directly would flip to "finished" at 00:00:01 on the trip's own
            // last day, cutting it a full day short.
            budgetTimingWidget = Chip(label: Text(l10n.tripFinished));
          } else {
            final daily = BudgetCalculator.remainingDailyBudget(
                trip: trip, expenses: expenses, asOf: now);
            budgetTimingWidget = daily == null
                ? const SizedBox.shrink()
                : Text(l10n.dailyBudgetRemaining(formatMoney(display(daily))));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(trip.name, style: Theme.of(context).textTheme.headlineSmall),
              Text('${formatDate(context, trip.startDate)} - ${formatDate(context, trip.endDate)}'),
              const SizedBox(height: 8),
              budgetTimingWidget,
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.totalBudget,
                          style: TextStyle(fontSize: 11, color: AppColors.mutedText)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatMoney(display(summary.totalBudget)),
                              style: Theme.of(context).textTheme.headlineMedium),
                          DropdownButton<String>(
                            value: displayCurrency,
                            underline: const SizedBox.shrink(),
                            items: {
                              trip.homeCurrency,
                              ...data.rates.map((r) => r.fromCurrency),
                            }.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (value) => setState(() => _viewCurrency = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _legendItem(context, AppColors.teal, l10n.actualLabel, display(summary.actualTotal)),
                          _legendItem(context, AppColors.gold, l10n.plannedLabel, display(summary.plannedTotal)),
                          _legendItem(context, AppColors.mutedText, l10n.remainingLabel, display(summary.remaining)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (breakdown.isNotEmpty) ...[
                Text(l10n.spendingByCategory, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Slices carry only the percentage — category name and exact
                // amount live in the legend list beside the chart instead, so
                // small slices never have to cram both a label and a number
                // into a sliver of pie.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: PieChart(PieChartData(sections: [
                        for (var i = 0; i < breakdown.length; i++)
                          PieChartSectionData(
                            value: breakdown[i].total.major,
                            title: '${breakdown[i].percentage.toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            color: AppColors.categoryChartColors[
                                kExpenseCategoryKeys.indexOf(breakdown[i].category) %
                                    AppColors.categoryChartColors.length],
                          ),
                      ])),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < breakdown.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.categoryChartColors[
                                          kExpenseCategoryKeys.indexOf(breakdown[i].category) %
                                              AppColors.categoryChartColors.length],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(categoryLabel(context, breakdown[i].category),
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  Text(formatMoney(breakdown[i].total),
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(l10n.noExpensesYet)),
                ),
              Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
              for (final expense in expenses)
                ListTile(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        trip: trip,
                        repository: widget.repository,
                        existingExpense: expense,
                      ),
                    ));
                    _refresh();
                  },
                  title: Text(expense.description.isEmpty
                      ? categoryLabel(context, expense.category)
                      : expense.description),
                  subtitle: Text(categoryLabel(context, expense.category)),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMoney(expense.amount)),
                      if (expense.status == ExpenseStatus.planned)
                        TextButton(
                          onPressed: () => _markAsSpent(expense),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(l10n.markAsSpent, style: const TextStyle(fontSize: 11)),
                        )
                      else
                        Text(l10n.actualLabel, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<_TripDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddExpenseScreen(trip: snapshot.data!.trip, repository: widget.repository),
              ));
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label, Money amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
        Text(formatMoney(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
