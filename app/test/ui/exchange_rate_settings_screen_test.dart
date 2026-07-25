// app/test/ui/exchange_rate_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/services/live_rate_service.dart';
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

  Widget wrap({LiveRateService? liveRateService, String? initialNewHomeCurrency}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExchangeRateSettingsScreen(
          trip: trip,
          repository: repo,
          liveRateService: liveRateService,
          initialNewHomeCurrency: initialNewHomeCurrency,
        ),
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

  testWidgets(
      'opening with initialNewHomeCurrency lands directly on the change-currency form, already '
      'targeting that currency', (tester) async {
    await tester.pumpWidget(wrap(initialNewHomeCurrency: 'JPY'));
    await tester.pumpAndSettle();

    // No need to tap "changeCurrencyButton" first, and no need to pick JPY
    // from the dropdown either — both already reflect the caller's choice.
    expect(find.byKey(const Key('changeCurrencyButton')), findsNothing);
    expect(find.byKey(const Key('directRateField_CNY')), findsOneWidget);
    expect(find.byKey(const Key('confirmChangeCurrencyButton')), findsOneWidget);

    // "1 JPY = ? CNY" — the new home currency first.
    await tester.enterText(find.byKey(const Key('directRateField_CNY')), '0.05');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'JPY');
  });

  testWidgets('checking and accepting the market rate fills in the new-rate field', (tester) async {
    final liveRateService = LiveRateService(
      client: MockClient((request) async =>
          http.Response('{"amount":1,"base":"CNY","date":"2026-07-25","rates":{"JPY":20.3}}', 200)),
    );
    await tester.pumpWidget(wrap(liveRateService: liveRateService));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newRateCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkMarketRateButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('20.3'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('newRateValueField'))).controller?.text,
        isEmpty);

    await tester.tap(find.byKey(const Key('acceptMarketRateButton')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byKey(const Key('newRateValueField'))).controller?.text,
        '20.3');
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
    // "1 JPY = 0.05 CNY" — the new home currency first, same direction as
    // every other rate field in the app ("1 home = ? foreign").
    await tester.enterText(find.byKey(const Key('directRateField_CNY')), '0.05');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'JPY');
    // Stored as "1 CNY = ? JPY" internally regardless of typed direction:
    // 1 / 0.05 = 20.
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

    // Shown both inline and as a SnackBar (see _showChangeCurrencyError).
    expect(find.textContaining('already the trip\'s home currency'), findsWidgets);

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CNY');
    expect(reloaded.totalBudget, Money.fromMajor(20000, 'CNY'), reason: 'budget must be untouched, not doubled');
  });

  testWidgets(
      'changing home currency in a trip with multiple currencies asks for a direct rate '
      'per currency, not just one', (tester) async {
    // Two direct-rate fields, each with its own market-rate helper, make
    // this form taller than the default test viewport's sliver layout
    // cache extent — widgets beyond it have no geometry at all (not just
    // "off-screen"), so enlarge the viewport rather than fight scrolling
    // mid-test for widgets this test needs to interact with one after
    // another.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // "1 CHF = 8 CNY" and "1 CHF = 170 JPY" — the new home currency (CHF)
    // first, matching the "1 home = ? foreign" direction used everywhere
    // else. Stored internally as the reciprocal: "1 CNY = 0.125 CHF" and
    // "1 JPY = ~0.005882 CHF".
    await tester.enterText(find.byKey(const Key('directRateField_CNY')), '8');
    await tester.enterText(find.byKey(const Key('directRateField_JPY')), '170');
    // The extra direct-rate fields (each with its own market-rate helper)
    // push the confirm button beyond the ListView sliver's layout cache
    // extent, where it has no geometry yet — ensureVisible can't locate an
    // unlaid-out target, so scroll incrementally instead.
    await tester.scrollUntilVisible(
      find.byKey(const Key('confirmChangeCurrencyButton')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CHF');
    expect(reloaded.totalBudget.major, closeTo(20000 * (1 / 8), 0.01));
    final rates = await repo.getExchangeRates('t1');
    final jpyRate = rates.firstWhere((r) => r.fromCurrency == 'JPY');
    expect(jpyRate.rate, closeTo(1 / 170, 0.0001),
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

  testWidgets(
      'confirming a currency change with one of several required rates left blank shows a '
      "SnackBar (not just an inline error that could be scrolled out of view) and doesn't change "
      'anything', (tester) async {
    // JPY already has a rate to the trip's CNY home currency, so changing
    // home currency now requires two direct-rate fields (CNY and JPY).
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newHomeCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHF').last);
    await tester.pumpAndSettle();

    // Only fill in CNY's rate, leaving JPY's blank.
    await tester.enterText(find.byKey(const Key('directRateField_CNY')), '0.13');
    await tester.scrollUntilVisible(
      find.byKey(const Key('confirmChangeCurrencyButton')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pump(); // SnackBar animates in
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Enter a positive exchange rate'), findsWidgets);
    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'CNY', reason: 'an incomplete change must not partially apply');
  });
}
