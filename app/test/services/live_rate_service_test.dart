import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelspendplus/services/live_rate_service.dart';

void main() {
  test('fetchRate returns the rate from a successful response', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.frankfurter.dev');
      expect(request.url.queryParameters['base'], 'CNY');
      expect(request.url.queryParameters['symbols'], 'JPY');
      return http.Response('{"amount":1,"base":"CNY","date":"2026-07-25","rates":{"JPY":20.3}}', 200);
    });
    final service = LiveRateService(client: client);

    final rate = await service.fetchRate(fromCurrency: 'CNY', toCurrency: 'JPY');

    expect(rate, 20.3);
  });

  test('fetchRate returns 1.0 without a network call when both currencies are the same', () async {
    final client = MockClient((request) async {
      fail('should not make a network call for a same-currency request');
    });
    final service = LiveRateService(client: client);

    final rate = await service.fetchRate(fromCurrency: 'CNY', toCurrency: 'CNY');

    expect(rate, 1.0);
  });

  test('fetchRate returns null on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('not found', 404));
    final service = LiveRateService(client: client);

    final rate = await service.fetchRate(fromCurrency: 'CNY', toCurrency: 'XYZ');

    expect(rate, isNull);
  });

  test('fetchRate returns null when the response body is unparseable', () async {
    final client = MockClient((request) async => http.Response('not json', 200));
    final service = LiveRateService(client: client);

    final rate = await service.fetchRate(fromCurrency: 'CNY', toCurrency: 'JPY');

    expect(rate, isNull);
  });

  test('fetchRate returns null when the requested currency is missing from the response',
      () async {
    final client = MockClient((request) async =>
        http.Response('{"amount":1,"base":"CNY","date":"2026-07-25","rates":{}}', 200));
    final service = LiveRateService(client: client);

    final rate = await service.fetchRate(fromCurrency: 'CNY', toCurrency: 'JPY');

    expect(rate, isNull);
  });

  test('fetchRate returns null when the client throws (e.g. no network)', () async {
    final client = MockClient((request) async => throw Exception('no network'));
    final service = LiveRateService(client: client);

    final rate = await service.fetchRate(fromCurrency: 'CNY', toCurrency: 'JPY');

    expect(rate, isNull);
  });
}
