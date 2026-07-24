import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/main.dart';
import 'package:travelspendplus/persistence/database.dart';
import 'package:travelspendplus/persistence/trip_repository.dart';

void main() {
  testWidgets('app builds and shows the trip list empty state', (tester) async {
    final db = AppDatabase.memory();
    final repo = TripRepository(db);
    await tester.pumpWidget(TravelSpendPlusApp(repository: repo));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noTripsYet), findsOneWidget);
    await db.close();
  });
}
