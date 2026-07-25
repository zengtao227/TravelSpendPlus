import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/civil_date.dart';

void main() {
  test('strips any time-of-day component from a fresh local value', () {
    final pickedLateInTheDay = DateTime(2026, 6, 15, 23, 45, 30);
    expect(civilDate(pickedLateInTheDay), DateTime.utc(2026, 6, 15));
  });

  test('is idempotent — normalizing an already-normalized value is a no-op', () {
    final already = DateTime.utc(2026, 6, 15);
    expect(civilDate(already), already);
  });

  test('recovers the exact original calendar day after a local-time decode of the same '
      'instant — this is the property the repository read path relies on: '
      'civilDate(persistedValue.toUtc()) always equals what was originally written, no '
      'matter which timezone the app happens to be running in when it reads the row back. '
      'NOTE: this only exercises the mechanism, not an actual cross-timezone device move — '
      'that would need the test process run under a different TZ env var, which this suite '
      "doesn't attempt; the repository round-trip tests cover the wiring in this process's "
      'own timezone.', () {
    final writtenInstant = DateTime.utc(2026, 1, 9); // what the repository always writes
    final asDecodedLocally =
        DateTime.fromMicrosecondsSinceEpoch(writtenInstant.microsecondsSinceEpoch, isUtc: false);
    expect(civilDate(asDecodedLocally.toUtc()), writtenInstant);
  });
}
