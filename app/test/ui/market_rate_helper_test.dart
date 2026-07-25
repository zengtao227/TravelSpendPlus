import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/services/live_rate_service.dart';
import 'package:travelspendplus/ui/market_rate_helper.dart';

void main() {
  Widget wrap(LiveRateService service, TextEditingController controller) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MarketRateHelper(
            fromCurrency: 'CNY',
            toCurrency: 'JPY',
            targetController: controller,
            liveRateService: service,
          ),
        ),
      );

  testWidgets(
      'checking the market rate shows the fetched value but leaves the field untouched until '
      'accepted', (tester) async {
    final controller = TextEditingController();
    final service = LiveRateService(
      client: MockClient((request) async =>
          http.Response('{"amount":1,"base":"CNY","date":"2026-07-25","rates":{"JPY":20.3}}', 200)),
    );

    await tester.pumpWidget(wrap(service, controller));
    await tester.tap(find.byKey(const Key('checkMarketRateButton')));
    await tester.pump(); // start the fetch (loading state)
    await tester.pumpAndSettle(); // fetch completes

    expect(controller.text, isEmpty, reason: 'must not auto-fill before the user accepts');
    expect(find.textContaining('20.3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('acceptMarketRateButton')));
    await tester.pump();

    expect(controller.text, '20.3');
  });

  testWidgets('a user-typed value survives if the market rate is never accepted', (tester) async {
    final controller = TextEditingController();
    final service = LiveRateService(
      client: MockClient((request) async =>
          http.Response('{"amount":1,"base":"CNY","date":"2026-07-25","rates":{"JPY":20.3}}', 200)),
    );

    await tester.pumpWidget(wrap(service, controller));
    controller.text = '19.5'; // the user already typed their own value
    await tester.tap(find.byKey(const Key('checkMarketRateButton')));
    await tester.pumpAndSettle();

    expect(controller.text, '19.5', reason: 'checking the market rate must not overwrite typing');
  });

  testWidgets('a failed lookup shows a fallback message and leaves manual entry as the only option',
      (tester) async {
    final controller = TextEditingController();
    final service = LiveRateService(
      client: MockClient((request) async => throw Exception('no network')),
    );

    await tester.pumpWidget(wrap(service, controller));
    await tester.tap(find.byKey(const Key('checkMarketRateButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('acceptMarketRateButton')), findsNothing);
    expect(find.text("Couldn't fetch a rate — enter one manually"), findsOneWidget);
  });
}
