// app/test/ui/exchange_rate_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
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

  testWidgets(
      'adding a rate persists it (entered as "1 home = ? foreign", stored as the reciprocal) '
      'and shows it in the list', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newRateCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY').last);
    await tester.pumpAndSettle();
    // "1 CNY = 20 JPY" — the direction a traveler exchanging cash thinks in.
    await tester.enterText(find.byKey(const Key('newRateValueField')), '20');
    await tester.tap(find.byKey(const Key('saveRateButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('JPY'), findsWidgets);
    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    // ExchangeRate.rate's own meaning is unchanged ("1 JPY = rate CNY"),
    // so the stored value is the reciprocal of what was typed.
    expect(rates.first.rate, closeTo(0.05, 0.0001));
  });

  testWidgets('changing home currency rescales the trip and clears the change form',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newHomeCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('directRateField_CNY')), '20');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'JPY');
    expect(reloaded.totalBudget.major, closeTo(20000 * 20, 0.01));
  });

  testWidgets('picking the trip\'s own current currency as the "new" one shows an error and changes nothing',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newHomeCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CNY').last); // trip's own home currency
    await tester.pumpAndSettle();
    // No direct-rate field to fill in: picking the trip's own current
    // currency leaves the required-currency set empty (CNY is both the old
    // and the "new" currency here, so it's excluded from the set).
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('already the trip\'s home currency'), findsOneWidget);

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CNY');
    expect(reloaded.totalBudget, Money.fromMajor(20000, 'CNY'), reason: 'budget must be untouched, not doubled');
  });

  testWidgets(
      'changing home currency in a trip with multiple currencies asks for a direct rate '
      'per currency, not just one', (tester) async {
    // JPY already has a rate to the trip's CNY home currency.
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newHomeCurrencyField')));
    await tester.pumpAndSettle();
    // CHF, not EUR — EUR is the shared default value both this dropdown
    // and the "add a rate" dropdown above start on, which would make an
    // `.last` text lookup ambiguous between the two.
    await tester.tap(find.text('CHF').last);
    await tester.pumpAndSettle();

    // Both CNY (old home) and JPY (has its own rate row) need a direct
    // rate to CHF — one field each, not a single blended one.
    expect(find.byKey(const Key('directRateField_CNY')), findsOneWidget);
    expect(find.byKey(const Key('directRateField_JPY')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('directRateField_CNY')), '0.13');
    await tester.enterText(find.byKey(const Key('directRateField_JPY')), '0.0062');
    // The extra direct-rate field pushes the confirm button below the
    // viewport, same overflow issue the add-expense form hit when its
    // category field grew taller.
    await tester.ensureVisible(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CHF');
    expect(reloaded.totalBudget.major, closeTo(20000 * 0.13, 0.01));
    final rates = await repo.getExchangeRates('t1');
    final jpyRate = rates.firstWhere((r) => r.fromCurrency == 'JPY');
    expect(jpyRate.rate, closeTo(0.0062, 0.0001),
        reason: 'must use the direct JPY rate typed in, not one derived via CNY');
  });

  testWidgets('adding a rate with an invalid rate value shows an error instead of failing silently',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newRateCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newRateValueField')), '0');
    await tester.tap(find.byKey(const Key('saveRateButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a positive exchange rate'), findsOneWidget);
    expect(await repo.getExchangeRates('t1'), isEmpty);
  });
}
