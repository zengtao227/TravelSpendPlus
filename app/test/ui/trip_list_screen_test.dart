import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/create_trip_screen.dart';
import 'package:travelspendplus/ui/trip_list_screen.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = TripRepository(db);
  });

  tearDown(() async => db.close());

  Widget wrap() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripListScreen(repository: repo),
      );

  testWidgets('shows an empty-state message when there are no trips', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('No trips yet — tap + to plan your first one'), findsOneWidget);
  });

  testWidgets('shows a card per trip with name and budget total', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [Participant(id: 'p1', name: 'Me')],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Japan Trip'), findsOneWidget);
    expect(find.textContaining('CNY 20,000.00'), findsWidgets);
  });

  testWidgets('the FAB navigates to CreateTripScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTripScreen), findsOneWidget);
  });
}
