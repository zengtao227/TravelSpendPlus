import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
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

  Widget wrap() => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddExpenseScreen(trip: trip, repository: repo),
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
}
