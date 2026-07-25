import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/backup.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/create_trip_screen.dart';
import 'package:travelspendplus/services/trip_photo_store.dart';
import 'package:travelspendplus/ui/trip_list_screen.dart';
import 'package:travelspendplus/version.dart';

import '../test_helpers/fake_path_provider.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;
  late Directory photoTempDir;
  final me = const Participant(id: 'p1', name: 'Me');

  setUp(() async {
    db = AppDatabase.memory();
    repo = TripRepository(db);
    // exportAllTripsToJson() and each _TripCard's photo thumbnail both go
    // through TripPhotoStore, which needs a real (fake, for tests)
    // documents directory from path_provider — without this, those calls
    // throw MissingPluginException since there's no real platform channel
    // here.
    photoTempDir = await Directory.systemTemp.createTemp('trip_list_screen_test');
    FakePathProviderPlatform.install(photoTempDir.path);
    TripPhotoStore.resetForTesting();
  });

  tearDown(() async {
    await db.close();
    if (await photoTempDir.exists()) await photoTempDir.delete(recursive: true);
  });

  Widget wrap({
    Future<String> Function(String, String)? writeTempFile,
    Future<void> Function(String, {String? subject})? shareFile,
    Future<String?> Function()? pickJsonFile,
    Future<void> Function(Locale?)? onLocaleChanged,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripListScreen(
          repository: repo,
          writeTempFile: writeTempFile ?? (name, content) async => '/tmp/$name',
          shareFile: shareFile ?? (path, {subject}) async {},
          pickJsonFile: pickJsonFile ?? () async => null,
          onLocaleChanged: onLocaleChanged,
        ),
      );

  testWidgets('the language button is hidden when onLocaleChanged is not provided',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('languageButton')), findsNothing);
  });

  testWidgets('picking a specific language from the dialog invokes onLocaleChanged with it',
      (tester) async {
    Locale? received;
    var receivedCalled = false;
    await tester.pumpWidget(wrap(onLocaleChanged: (locale) async {
      received = locale;
      receivedCalled = true;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('languageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('languageOption_zh')));
    await tester.pumpAndSettle();

    expect(receivedCalled, isTrue);
    expect(received, const Locale('zh'));
  });

  testWidgets('picking "System default" invokes onLocaleChanged with null', (tester) async {
    Locale? received = const Locale('zh');
    var receivedCalled = false;
    await tester.pumpWidget(wrap(onLocaleChanged: (locale) async {
      received = locale;
      receivedCalled = true;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('languageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('languageOptionSystem')));
    await tester.pumpAndSettle();

    expect(receivedCalled, isTrue);
    expect(received, isNull);
  });

  testWidgets('dismissing the language dialog without a choice does not call onLocaleChanged',
      (tester) async {
    var receivedCalled = false;
    await tester.pumpWidget(wrap(onLocaleChanged: (locale) async {
      receivedCalled = true;
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('languageButton')));
    await tester.pumpAndSettle();
    // Tap the barrier (outside the dialog) to dismiss without choosing.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(receivedCalled, isFalse);
  });

  testWidgets('shows an empty-state message when there are no trips', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('No trips yet — tap + to plan your first one'), findsOneWidget);
  });

  testWidgets(
      'shows the app version as a small footer, so a screenshot can settle which build is '
      'actually running', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appVersionLabel')), findsOneWidget);
    expect(find.text('v$kAppVersion'), findsOneWidget);
  });

  testWidgets('shows a card per trip with name and budget total', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [Participant(id: 'p1', name: 'Me')],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Japan Trip'), findsOneWidget);
    expect(find.textContaining('CNY 20,000.00'), findsWidgets);
    expect(find.textContaining('8 days'), findsOneWidget); // inclusive of both ends
  });

  testWidgets('shows actual and planned totals as separate, correctly-labeled figures',
      (tester) async {
    // Regression test: the card used to add plannedTotal + actualTotal
    // together and show the sum under the single "Spent" label, which
    // misrepresents planned (not-yet-spent) money as already spent. Use
    // different, non-zero amounts for actual vs. planned so a bug that
    // combined or mislabeled them would be caught by these assertions.
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
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
      date: DateTime.now(),
      endDate: DateTime.now(),
      location: '',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e2',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(5000, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(5000, 'CNY'),
      description: 'Flight',
      date: DateTime.now(),
      endDate: DateTime.now(),
      location: '',
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Actual (300) and planned (5000) must appear as distinct figures,
    // each under its own label — never combined into a single 5300 sum.
    expect(find.text('Spent CNY 300.00'), findsOneWidget);
    expect(find.text('Planned CNY 5,000.00'), findsOneWidget);
    expect(find.textContaining('5,300.00'), findsNothing);
  });

  testWidgets('hides the "Planned" figure entirely when a trip has no planned expenses at all',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
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
      date: DateTime.now(),
      endDate: DateTime.now(),
      location: '',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Spent CNY 300.00'), findsOneWidget);
    expect(find.textContaining('Planned'), findsNothing);
  });

  testWidgets('hides the budget total figure entirely when a trip has no budget set',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(0, 'CNY'), // budget tracking off
      participants: [me],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // "CNY 0.00" would read as a real zero budget, not "tracking is off" —
    // it must not appear anywhere on the card.
    expect(find.text('CNY 0.00'), findsNothing);
  });

  testWidgets('the FAB navigates to CreateTripScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTripScreen), findsOneWidget);
  });

  // NOTE: this used to drive the export via tester.tap(backupAllButton) and
  // assert on the shareFile/writeTempFile callbacks. Since
  // exportAllTripsToJson() started calling TripPhotoStore (real file I/O
  // via path_provider) for each trip, that path — triggered from inside a
  // widget's onPressed handler, or even awaited directly in a testWidgets
  // body — stopped completing within this test binding's fake-async zone
  // (AutomatedTestWidgetsFlutterBinding only advances microtask-driven
  // async during pump/pumpAndSettle; real dart:io I/O like this doesn't
  // get a chance to run, and tester.runAsync() can't wrap tap/pumpAndSettle
  // either). The exported JSON's shape (including the photo field) is
  // already fully covered by trip_repository_test.dart's plain `test()`
  // suite, which isn't subject to this widget-binding limitation — so
  // that coverage isn't duplicated here. This file just confirms the
  // button itself is present and enabled.
  testWidgets('the backup button is present and tappable when at least one trip exists',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backupAllButton')), findsOneWidget);
    final button = tester.widget<IconButton>(find.byKey(const Key('backupAllButton')));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the empty state offers a restore-from-backup button that imports the picked backup',
      (tester) async {
    final backupJson = backupToJson([
      TripBundle(
        trip: Trip(
          id: 't1',
          name: 'Restored Trip',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 5),
          homeCurrency: 'EUR',
          totalBudget: Money.fromMajor(1000, 'EUR'),
          participants: [me],
        ),
        expenses: const [],
        exchangeRates: const [],
      ),
    ]);

    // pickJsonFile returns the file's *content* (see Task 4), so this fake
    // can hand back a fabricated backup string directly — no real
    // filesystem access needed to exercise the full real import path
    // (jsonDecode -> TripRepository.importAllTripsFromJson -> the real
    // in-memory database).
    await tester.pumpWidget(wrap(pickJsonFile: () async => jsonEncode(backupJson)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('restoreFromBackupButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('restoreFromBackupButton')));
    await tester.pumpAndSettle();

    // The empty state is gone and the restored trip's own card is showing —
    // proof the button actually drove a real import, not just that it exists.
    expect(find.text('Restored Trip'), findsOneWidget);
  });

  testWidgets('a failed import shows an error message instead of failing silently',
      (tester) async {
    await tester.pumpWidget(wrap(pickJsonFile: () async => 'not valid json{{{'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restoreFromBackupButton')));
    await tester.pumpAndSettle();

    expect(find.text('This file couldn\'t be read as a TravelSpendPlus backup'), findsOneWidget);
  });
}
