import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches a live market exchange rate from Frankfurter
/// (https://frankfurter.dev — European Central Bank reference rates, free,
/// no API key required) as an optional convenience alongside manual rate
/// entry, which remains the primary path everywhere this is used.
///
/// [fetchRate] returns null on any failure — offline, an unsupported
/// currency, a non-200 response, an unparseable body — and callers treat a
/// null result as "no live rate available right now," falling back to
/// manual entry silently rather than surfacing a hard error.
class LiveRateService {
  final http.Client _client;

  LiveRateService({http.Client? client}) : _client = client ?? http.Client();

  /// "1 [fromCurrency] = ? [toCurrency]" — the same direction used
  /// throughout the app's own rate-entry fields.
  Future<double?> fetchRate({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return 1.0;
    final uri = Uri.https('api.frankfurter.dev', '/v1/latest', {
      'base': fromCurrency,
      'symbols': toCurrency,
    });
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final rates = body['rates'];
      if (rates is! Map<String, dynamic>) return null;
      final rate = rates[toCurrency];
      return rate is num ? rate.toDouble() : null;
    } catch (_) {
      return null;
    }
  }
}
