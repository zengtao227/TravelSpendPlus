import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/add_expense_screen.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;
  late Trip trip;

  setUp(() async {
    db = AppDatabase.memory();
    repo = TripRepository(db);
    trip = Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [const Participant(id: 'p1', name: 'Me')],
    );
    await repo.createTrip(trip);
  });

  tearDown(() async => db.close());

  Widget wrap({Expense? existingExpense}) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddExpenseScreen(trip: trip, repository: repo, existingExpense: existingExpense),
      );

  testWidgets('filling a valid home-currency expense saves it as actual by default',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '300');
    await tester.enterText(find.byKey(const Key('expenseDescriptionField')), 'Visa fee');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.length, 1);
    expect(expenses.first.category, 'food');
    expect(expenses.first.amount, Money.fromMajor(300, 'CNY'));
    expect(expenses.first.status, ExpenseStatus.actual);
    expect(expenses.first.paidBy.id, 'p1');
    expect(expenses.first.paidFor.map((p) => p.id).toList(), ['p1']);
  });

  testWidgets('choosing Planned status saves a planned expense', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3200');
    await tester.tap(find.text('计划中'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.status, ExpenseStatus.planned);
    expect(expenses.first.includeInSplit, isTrue);
  });

  testWidgets('an unknown foreign currency prompts for its exchange rate and saves it for reuse',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('住宿').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '10000');
    await tester.enterText(find.byKey(const Key('expenseCurrencyField')), 'JPY');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenseExchangeRateField')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expenseExchangeRateField')), '0.05');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amount, Money.fromMajor(10000, 'JPY'));
    expect(expenses.first.amountInHomeCurrency.major, closeTo(500, 0.01));
    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.fromCurrency, 'JPY');
  });

  testWidgets('empty category shows a validation error and does not save', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '30');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    expect(find.text('请选择类别'), findsOneWidget);
    expect(await repo.getExpenses('t1'), isEmpty);
  });

  testWidgets('edit mode pre-fills every field from the existing expense', (tester) async {
    final me = trip.participants.first;
    final existing = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'lodging',
      amount: Money.fromMajor(2800, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(2800, 'CNY'),
      description: 'Kyoto guesthouse',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    );
    await repo.addExpense(existing);

    await tester.pumpWidget(wrap(existingExpense: existing));
    await tester.pumpAndSettle();

    expect(find.text('编辑支出'), findsOneWidget); // AppBar title, not "记一笔"
    expect(find.text('住宿'), findsOneWidget); // pre-selected category label
    expect(find.text('2800.0'), findsOneWidget); // amount field
    expect(find.text('Kyoto guesthouse'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget); // save button says "save changes", not "记一笔的保存"
  });

  testWidgets('edit mode saves via updateExpense, keeping the same id and not creating a second row',
      (tester) async {
    final me = trip.participants.first;
    final existing = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'lodging',
      amount: Money.fromMajor(2800, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(2800, 'CNY'),
      description: 'Kyoto guesthouse',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    );
    await repo.addExpense(existing);

    await tester.pumpWidget(wrap(existingExpense: existing));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3100');
    await tester.enterText(
        find.byKey(const Key('expenseDescriptionField')), 'Kyoto guesthouse (extra night)');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.length, 1, reason: 'editing must update the row, not add a second one');
    expect(expenses.first.id, 'e1');
    expect(expenses.first.amount, Money.fromMajor(3100, 'CNY'));
    expect(expenses.first.description, 'Kyoto guesthouse (extra night)');
    expect(expenses.first.category, 'lodging', reason: 'untouched fields must be preserved');
    expect(expenses.first.status, ExpenseStatus.planned, reason: 'untouched fields must be preserved');
  });

  testWidgets(
      'editing an unrelated field on a foreign-currency expense preserves the exchange rate locked in at recording time',
      (tester) async {
    final me = trip.participants.first;
    // Recorded at 1 JPY = 0.05 CNY: 10000 JPY -> 500 CNY.
    await repo.setExchangeRate('t1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05));
    final existing = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(10000, 'JPY'),
      amountInHomeCurrency: Money.fromMajor(500, 'CNY'),
      description: 'Flight',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    );
    await repo.addExpense(existing);

    // The trip's JPY rate changes later (e.g. a different expense recorded
    // afterwards at a new rate) — this must NOT retroactively change what
    // the 10000 JPY flight above is worth in CNY.
    await repo.setExchangeRate('t1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.04));

    await tester.pumpWidget(wrap(existingExpense: existing));
    await tester.pumpAndSettle();
    // Only touch an unrelated field — amount and currency stay as they were.
    await tester.enterText(find.byKey(const Key('expenseDescriptionField')), 'Flight (updated note)');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amount, Money.fromMajor(10000, 'JPY'));
    expect(expenses.first.amountInHomeCurrency.major, closeTo(500, 0.01),
        reason: 'must stay locked to the 0.05 rate in effect when this expense was recorded, '
            'not silently jump to 400 (10000 * the now-current 0.04 rate)');
  });

  testWidgets('editing the amount of a foreign-currency expense rescales proportionally from its own locked rate',
      (tester) async {
    final me = trip.participants.first;
    await repo.setExchangeRate('t1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05));
    final existing = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(10000, 'JPY'),
      amountInHomeCurrency: Money.fromMajor(500, 'CNY'),
      description: 'Flight',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    );
    await repo.addExpense(existing);
    // Rate table moves on; the edit below must still use the *original*
    // 500/10000 = 0.05 ratio implied by this expense's own recorded values.
    await repo.setExchangeRate('t1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.04));

    await tester.pumpWidget(wrap(existingExpense: existing));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '20000'); // double the JPY amount
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amount, Money.fromMajor(20000, 'JPY'));
    expect(expenses.first.amountInHomeCurrency.major, closeTo(1000, 0.01),
        reason: 'doubling the JPY amount should double the CNY total using the rate this '
            'expense was originally recorded at (500*2=1000), not the current 0.04 rate (which '
            'would give 800)');
  });
}
