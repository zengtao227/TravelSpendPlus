import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/persistence/database.dart'
    hide Participant, Trip;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/category_settings_screen.dart';

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
      participants: const [Participant(id: 'p1', name: 'Me')],
    );
    await repo.createTrip(trip);
  });

  tearDown(() => db.close());

  Widget wrap() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CategorySettingsScreen(trip: trip, repository: repo),
  );

  testWidgets('renames a built-in category and changes its icon', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCategory-food')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('categorySettingsNameField')),
      'Meals',
    );
    await tester.tap(find.byKey(const Key('categoryIcon-shopping')));
    await tester.tap(find.byKey(const Key('saveCategorySettingsButton')));
    await tester.pumpAndSettle();

    final setting = (await repo.getCategorySettings(
      't1',
    )).singleWhere((value) => value.key == 'food');
    expect(setting.displayName, 'Meals');
    expect(setting.iconKey, 'shopping');
    expect(find.text('Meals'), findsOneWidget);
  });

  testWidgets('adds a custom category with a selected icon', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('categorySettingsNameField')),
      'Museum',
    );
    await tester.tap(find.byKey(const Key('categoryIcon-tickets')));
    await tester.tap(find.byKey(const Key('saveCategorySettingsButton')));
    await tester.pumpAndSettle();

    final setting = (await repo.getCategorySettings(
      't1',
    )).singleWhere((value) => value.displayName == 'Museum');
    expect(setting.key, startsWith('custom_'));
    expect(setting.iconKey, 'tickets');
    expect(setting.hidden, isFalse);
    expect(find.text('Museum'), findsOneWidget);
  });

  testWidgets('rejects a category name already used by a built-in category', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addCategoryButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('categorySettingsNameField')),
      'Food',
    );
    await tester.tap(find.byKey(const Key('saveCategorySettingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('This category already exists'), findsOneWidget);
    expect(await repo.getCategorySettings('t1'), isEmpty);
  });

  testWidgets('hides and restores without changing the category key', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hideCategory-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmHideCategory-food')));
    await tester.pumpAndSettle();

    var setting = (await repo.getCategorySettings(
      't1',
    )).singleWhere((value) => value.key == 'food');
    expect(setting.hidden, isTrue);
    expect(find.text('Hidden'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restoreCategory-food')));
    await tester.pumpAndSettle();
    expect(await repo.getAvailableCategoryKeys('t1'), contains('food'));
    expect(
      (await repo.getCategorySettings(
        't1',
      )).where((value) => value.key == 'food'),
      isEmpty,
      reason:
          'Restoring the untouched built-in returns it to its default state.',
    );
  });
}
