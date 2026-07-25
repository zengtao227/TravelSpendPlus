import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/main.dart';
import 'package:travelspendplus/persistence/database.dart';
import 'package:travelspendplus/persistence/trip_repository.dart';

void main() {
  // loadLocaleOverride/saveLocaleOverride are stubbed in every test below —
  // the real implementations go through the shared_preferences plugin
  // channel, which isn't available in a plain widget-test environment.
  testWidgets('app builds and shows the trip list empty state', (tester) async {
    final db = AppDatabase.memory();
    final repo = TripRepository(db);
    await tester.pumpWidget(TravelSpendPlusApp(
      repository: repo,
      loadLocaleOverride: () async => null,
      saveLocaleOverride: (_) async {},
    ));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noTripsYet), findsOneWidget);
    await db.close();
  });

  testWidgets('loads and applies a persisted locale override on startup', (tester) async {
    final db = AppDatabase.memory();
    final repo = TripRepository(db);
    await tester.pumpWidget(TravelSpendPlusApp(
      repository: repo,
      loadLocaleOverride: () async => 'zh',
      saveLocaleOverride: (_) async {},
    ));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.noTripsYet), findsOneWidget);
    await db.close();
  });

  testWidgets('picking a language in the switcher persists it and updates the UI',
      (tester) async {
    final db = AppDatabase.memory();
    final repo = TripRepository(db);
    String? saved;
    var saveCallCount = 0;
    await tester.pumpWidget(TravelSpendPlusApp(
      repository: repo,
      loadLocaleOverride: () async => null,
      saveLocaleOverride: (code) async {
        saved = code;
        saveCallCount++;
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('languageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('languageOption_zh')));
    await tester.pumpAndSettle();

    expect(saveCallCount, 1);
    expect(saved, 'zh');
    final zhL10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(zhL10n.noTripsYet), findsOneWidget);
    await db.close();
  });

  testWidgets('the test-only locale override hides the language switcher entirely',
      (tester) async {
    final db = AppDatabase.memory();
    final repo = TripRepository(db);
    await tester.pumpWidget(TravelSpendPlusApp(
      repository: repo,
      locale: const Locale('zh'),
      loadLocaleOverride: () async => throw StateError('must not be called when locale is set'),
      saveLocaleOverride: (_) async {},
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('languageButton')), findsNothing);
    await db.close();
  });
}
