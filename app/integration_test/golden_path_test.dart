// app/integration_test/golden_path_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travelspendplus/main.dart';
import 'package:travelspendplus/persistence/database.dart';
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/trip_detail_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('golden path: create trip -> add planned expense -> mark as spent -> edit expense',
      (tester) async {
    final db = await AppDatabase.openOnDevice();
    final repo = TripRepository(db);
    // Pin the locale explicitly — this test asserts hardcoded Chinese
    // strings, and must not depend on the test device/emulator's own
    // system locale happening to already be zh (it previously only passed
    // because the dev emulator was set to zh-CN).
    await tester.pumpWidget(TravelSpendPlusApp(repository: repo, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // Create a trip.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripNameField')), 'Golden Path Japan');
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '20000');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();
    expect(find.text('Golden Path Japan'), findsOneWidget);

    // Open the trip.
    await tester.tap(find.text('Golden Path Japan'));
    await tester.pumpAndSettle();
    expect(find.byType(TripDetailScreen), findsOneWidget);

    // Add a planned expense.
    await tester.tap(find.byType(FloatingActionButton));
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

    // Back on the detail screen: the planned expense shows, mark it as spent.
    expect(find.text('标记为已发生'), findsOneWidget);
    await tester.tap(find.text('标记为已发生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('标记为已发生'), findsNothing);

    // Edit the now-actual expense (added after Task 13 was first written —
    // AddExpenseScreen gained edit mode, opened by tapping the row itself).
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();
    expect(find.text('编辑支出'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3500');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    // Verify against the real on-device database directly, not just the UI.
    final trips = await repo.getAllTrips();
    final trip = trips.firstWhere((t) => t.name == 'Golden Path Japan');
    final expenses = await repo.getExpenses(trip.id);
    expect(expenses.single.status.toString(), contains('actual'));
    expect(expenses.single.amount.major, 3500.0);

    await db.close();
  });
}
