// app/test/ui/trip_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/add_expense_screen.dart';
import 'package:travelspendplus/ui/exchange_rate_settings_screen.dart';
import 'package:travelspendplus/ui/trip_detail_screen.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;
  final me = const Participant(id: 'p1', name: 'Me');

  setUp(() {
    db = AppDatabase.memory();
    repo = TripRepository(db);
  });

  tearDown(() async => db.close());

  Widget wrap(
    String tripId, {
    Future<String> Function(String, String)? writeTempFile,
    Future<void> Function(String, {String? subject})? shareFile,
  }) =>
      MaterialApp(
        locale: const Locale('zh'), // tests tap/assert Chinese labels below; pin the locale explicitly
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripDetailScreen(
          tripId: tripId,
          repository: repo,
          writeTempFile: writeTempFile ?? (name, content) async => '/tmp/$name',
          shareFile: shareFile ?? (path, {subject}) async {},
        ),
      );

  testWidgets('the date range shows the trip length in days', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12), // inclusive of both ends = 8 days
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('8天'), findsOneWidget);
  });

  testWidgets('a not-yet-departed trip shows a countdown, not a daily budget', (tester) async {
    final farFuture = DateTime.now().add(const Duration(days: 30));
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: farFuture,
      endDate: farFuture.add(const Duration(days: 7)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('30'), findsWidgets);
    // Locale is pinned to zh (see wrap()); the daily-budget suffix is
    // localized too ("/天", not "/day" — app_zh.arb's dailyBudgetRemaining
    // translates the whole string, unlike the English source), so probe
    // for the zh text, not the English one.
    expect(find.textContaining('/天'), findsNothing);
  });

  testWidgets('an in-progress trip shows the daily remaining budget', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    // See the comment in the first test: app_zh.arb's dailyBudgetRemaining
    // renders ".../天", not "/day" — the locale is pinned to zh here. The
    // average-daily-spend line also ends in "/天" once the trip has started
    // (it's independent of the budget), so match on its distinct prefix
    // rather than the shared suffix.
    expect(find.textContaining('每日剩余预算'), findsOneWidget);
    expect(find.textContaining('目前日均花费'), findsOneWidget);
  });

  testWidgets('the average-daily-spend line reflects actual spend regardless of budget',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)), // 3 elapsed days incl. today
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(0, 'CNY'), // no budget set
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Visa fee',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    // 300 / 3 elapsed days = 100.00/day, shown even though totalBudget is 0.
    expect(find.textContaining('目前日均花费'), findsOneWidget);
    expect(find.textContaining('100.00'), findsWidgets);
    // With no budget set, "remaining" is just the negative of what's been
    // spent — not a meaningful number, so it isn't shown at all.
    expect(find.text('预计还剩'), findsNothing);
  });

  testWidgets('a trip with a budget set still shows the "remaining" figure', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.text('预计还剩'), findsOneWidget);
  });

  testWidgets('a finished trip shows a static "trip finished" summary', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 20)),
      endDate: DateTime.now().subtract(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.text('行程已结束'), findsOneWidget);
    // No more remaining-daily-budget line once finished, but the
    // average-daily-spend line still shows (it's meaningful for the whole
    // finished trip, unlike remaining-budget).
    expect(find.textContaining('每日剩余预算'), findsNothing);
    expect(find.textContaining('目前日均花费'), findsOneWidget);
  });

  testWidgets('a trip on its own last calendar day still shows the daily budget, not finished',
      (tester) async {
    // Regression test: comparing `DateTime.now()` (a specific instant)
    // directly against `endDate` (stored at midnight) used to flip to
    // "finished" the moment any time passed on the trip's own last day,
    // cutting it a day short. endDate = today (midnight) must still count
    // as in-progress for the whole day.
    final today = DateTime.now();
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: today.subtract(const Duration(days: 6)),
      endDate: DateTime(today.year, today.month, today.day),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.text('行程已结束'), findsNothing);
    expect(find.textContaining('每日剩余预算'), findsOneWidget);
  });

  testWidgets('the category legend shows each category name and its exact amount, not just percentages in the pie',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Dinner',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e2',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(3200, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(3200, 'CNY'),
      description: 'Taxi',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    // '餐饮'/'交通' also appear as each expense list row's subtitle, so the
    // legend contributes at least one more occurrence of each, not exactly
    // one overall.
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('交通'), findsWidgets);
    expect(find.textContaining('300.00'), findsWidgets);
    expect(find.textContaining('3,200.00'), findsWidgets);
  });

  testWidgets('an actual expense is reflected in totals and the category chart', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Visa fee',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Visa fee'), findsOneWidget);
  });

  testWidgets('tapping "mark as spent" on a planned expense converts it to actual',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(3200, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(3200, 'CNY'),
      description: 'Flight',
      date: DateTime.now(),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    // The expense list sits below the budget card + pie chart in a
    // ListView, so on the default 800x600 test surface the "mark as
    // spent" button can land right at (or past) the bottom edge —
    // scroll it fully into view before tapping rather than assume it's
    // already on-screen.
    await tester.ensureVisible(find.text('标记为已发生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记为已发生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.status, ExpenseStatus.actual);
  });

  testWidgets('the FAB navigates to AddExpenseScreen', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(AddExpenseScreen), findsOneWidget);
  });

  testWidgets('tapping an expense row opens it for editing, and saving there updates it in place',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'lodging',
      amount: Money.fromMajor(2800, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(2800, 'CNY'),
      description: 'Kyoto guesthouse',
      date: DateTime.now(),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kyoto guesthouse'));
    await tester.pumpAndSettle();
    expect(find.byType(AddExpenseScreen), findsOneWidget);
    expect(find.text('编辑支出'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3000');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.length, 1);
    expect(expenses.first.amount, Money.fromMajor(3000, 'CNY'));
  });

  testWidgets(
      'changing home currency via the exchange-rate icon is reflected on the trip page after '
      'navigating back', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(1000, 'EUR'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('EUR'), findsWidgets);

    await tester.tap(find.byIcon(Icons.currency_exchange));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newHomeCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHF').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('directRateField_EUR')), '0.95');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    // Back on the trip page: both the in-memory widget and a fresh DB read
    // must agree the home currency actually changed and stuck. The expense
    // itself (recorded in EUR) correctly keeps showing "EUR 30.00" in its
    // own row — only the trip's home currency changed, not each expense's
    // own recorded currency — so check the *summary card* specifically,
    // not "no EUR text anywhere on the page."
    expect(find.byType(ExchangeRateSettingsScreen), findsNothing);
    expect(find.text('CHF 950.00'), findsOneWidget); // 1000 EUR * 0.95
    var reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CHF');

    // Then edit the existing expense (still EUR-denominated, unaffected by
    // the home-currency change) and save it without touching its currency
    // — this alone must not revert the trip's home currency back to EUR.
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '35');
    await tester.ensureVisible(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    expect(find.text('CHF 950.00'), findsOneWidget, reason: 'budget must still read in CHF');
    reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CHF', reason: 'editing an unrelated expense field must not revert the home currency');
  });

  testWidgets(
      'changing home currency to a currency that already has expenses recorded in it (CHF is '
      'also the dropdown\'s own default "other" currency for a EUR-home trip, so this reaches '
      'the target without ever tapping the currency dropdown)', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Switzerland',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(1000, 'EUR'),
      participants: [me],
    ));
    // 1 CHF = 1.05 EUR
    await repo.setExchangeRate('t1', const ExchangeRate(fromCurrency: 'CHF', toCurrency: 'EUR', rate: 1.05));
    await repo.addExpense(Expense(
      id: 'e-eur',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e-chf',
      tripId: 't1',
      category: 'lodging',
      amount: Money.fromMajor(200, 'CHF'),
      amountInHomeCurrency: Money.fromMajor(210, 'EUR'),
      description: 'Hotel',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.currency_exchange));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();

    // CHF is already selected without tapping the dropdown — confirm the
    // one required rate field (EUR) is actually there to fill in.
    expect(find.byKey(const Key('directRateField_EUR')), findsOneWidget);
    expect(find.byKey(const Key('directRateField_CHF')), findsNothing,
        reason: 'CHF is becoming the home currency, it needs no rate to itself');

    await tester.enterText(find.byKey(const Key('directRateField_EUR')), '0.95');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ExchangeRateSettingsScreen), findsNothing);
    expect(find.text('CHF 950.00'), findsOneWidget);
    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CHF');
    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.fromCurrency, 'EUR');
    expect(rates.first.toCurrency, 'CHF');
  });

  testWidgets('the category legend follows the currency switcher, not just the summary card',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    // 1 JPY = 0.05 CNY, so 1 CNY = 20 JPY.
    await repo.setExchangeRate('t1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(100, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(100, 'CNY'),
      description: 'Dinner',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CNY 100.00'), findsWidgets, reason: 'legend defaults to home currency');

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('JPY 2,000.00'), findsWidgets,
        reason: 'legend must follow the same view-currency switch as the summary card '
            '(100 CNY * 20 = 2000 JPY), not stay stuck showing home-currency amounts');
  });

  testWidgets('deleting a trip removes it, its expenses, and pops back to the caller',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Dinner',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    bool? poppedResult;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            poppedResult = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(tripId: 't1', repository: repo),
              ),
            );
          },
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteTripButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteTripButton')));
    await tester.pumpAndSettle();

    expect(await repo.getTrip('t1'), isNull);
    expect(await repo.getExpenses('t1'), isEmpty);
    expect(poppedResult, isTrue);
    expect(find.text('open'), findsOneWidget); // back on the caller screen
  });

  testWidgets('cancelling the delete-trip confirmation keeps the trip', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteTripButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await repo.getTrip('t1'), isNotNull);
  });

  testWidgets('the CSV export button shares a file containing one row per expense',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    );
    await repo.createTrip(trip);
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Dinner',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    String? writtenContent;
    await tester.pumpWidget(wrap(
      't1',
      writeTempFile: (name, content) async {
        writtenContent = content;
        return '/tmp/$name';
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportTripCsvButton')));
    await tester.pumpAndSettle();

    expect(writtenContent, isNotNull);
    expect(writtenContent, contains('Dinner'));
    expect(writtenContent, contains('2026-10-06'));
  });
}
