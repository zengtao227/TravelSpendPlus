// app/test/ui/trip_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/add_expense_screen.dart';
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

  Widget wrap(String tripId) => MaterialApp(
        locale: const Locale('zh'), // tests tap/assert Chinese labels below; pin the locale explicitly
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripDetailScreen(tripId: tripId, repository: repo),
      );

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
    // renders ".../天", not "/day" — the locale is pinned to zh here.
    expect(find.textContaining('/天'), findsOneWidget);
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
    expect(find.textContaining('/天'), findsNothing);
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
}
