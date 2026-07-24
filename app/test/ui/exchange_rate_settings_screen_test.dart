// app/test/ui/exchange_rate_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/exchange_rate_settings_screen.dart';

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExchangeRateSettingsScreen(trip: trip, repository: repo),
      );

  testWidgets('adding a rate persists it and shows it in the list', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newRateCurrencyField')), 'JPY');
    await tester.enterText(find.byKey(const Key('newRateValueField')), '0.05');
    await tester.tap(find.byKey(const Key('saveRateButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('JPY'), findsWidgets);
    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.rate, 0.05);
  });

  testWidgets('changing home currency rescales the trip and clears the change form',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newHomeCurrencyField')), 'JPY');
    await tester.enterText(find.byKey(const Key('oldToNewRateField')), '20');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'JPY');
    expect(reloaded.totalBudget.major, closeTo(20000 * 20, 0.01));
  });

  testWidgets('entering the trip\'s own current currency as the "new" one shows an error and changes nothing',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newHomeCurrencyField')), 'CNY'); // trip's own home currency
    await tester.enterText(find.byKey(const Key('oldToNewRateField')), '2');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('already the trip\'s home currency'), findsOneWidget);

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CNY');
    expect(reloaded.totalBudget, Money.fromMajor(20000, 'CNY'), reason: 'budget must be untouched, not doubled');
  });
}
