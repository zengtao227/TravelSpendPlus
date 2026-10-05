import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travelspendplus/domain/civil_date.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/persistence/database.dart'
    hide Expense, Participant, Trip;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/add_expense_screen.dart';
import 'package:travelspendplus/ui/theme.dart';
import 'package:travelspendplus/ui/trip_detail_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'daily shares and expense form render on Android with navigation insets',
    (tester) async {
      final db = AppDatabase.memory();
      final repo = TripRepository(db);
      const me = Participant(id: 'daily-me', name: 'Me');
      final today = civilDate(DateTime.now());
      final trip = Trip(
        id: 'daily-preview',
        name: 'Daily expenses',
        startDate: today,
        endDate: today.add(const Duration(days: 9)),
        homeCurrency: 'EUR',
        totalBudget: Money.fromMajor(2000, 'EUR'),
        participants: [me],
      );
      await repo.createTrip(trip);
      final lodging = Expense(
        id: 'daily-lodging',
        tripId: trip.id,
        category: 'lodging',
        amount: Money.fromMajor(1000, 'EUR'),
        amountInHomeCurrency: Money.fromMajor(1000, 'EUR'),
        description: 'Hotel',
        date: today,
        endDate: trip.endDate,
        location: 'Zurich',
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: me,
        paidFor: [me],
      );
      await repo.addExpense(lodging);
      await repo.addExpense(
        lodging.copyWith(
          id: 'daily-coffee',
          category: 'drinks',
          description: 'Coffee',
          amount: Money.fromMajor(50, 'EUR'),
          amountInHomeCurrency: Money.fromMajor(50, 'EUR'),
          endDate: today,
        ),
      );
      Widget wrap(Widget screen) => MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      );
      await tester.pumpWidget(
        wrap(TripDetailScreen(tripId: trip.id, repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('150.00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final detailImage = await binding.takeScreenshot('daily-detail');
      final detailPath = '${Directory.systemTemp.path}/daily-detail.png';
      await File(detailPath).writeAsBytes(detailImage);
      // A fixture database keeps verification separate from the device's real trips.
      tester.state<NavigatorState>(find.byType(Navigator)).push<void>(
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            trip: trip,
            repository: repo,
            existingExpense: lodging,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('saveExpenseButton'));
      await tester.scrollUntilVisible(save, 250, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      final view = tester.view;
      final safeBottom =
          (view.physicalSize.height - view.padding.bottom) /
          view.devicePixelRatio;
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(safeBottom));
      final formImage = await binding.takeScreenshot('daily-form');
      await File(
        '${Directory.systemTemp.path}/daily-form.png',
      ).writeAsBytes(formImage);
      final amountField = find.byKey(const Key('expenseAmountField'));
      await tester.scrollUntilVisible(amountField, -250, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      await tester.tap(amountField);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(save, 250, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      final keyboardTop =
          (view.physicalSize.height - view.viewInsets.bottom) /
          view.devicePixelRatio;
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(keyboardTop));
      await tester.tap(save);
      await tester.pumpAndSettle();
      final restored = (await repo.getExpenses(
        trip.id,
      )).firstWhere((e) => e.id == lodging.id);
      expect(restored.spreadAcrossDays, isTrue);
      expect(restored.createdAt, lodging.createdAt);
      expect(tester.takeException(), isNull);
      await db.close();
    },
  );
}
