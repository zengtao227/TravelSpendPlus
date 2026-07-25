import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/create_trip_screen.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = TripRepository(db);
    // The photo picker avatar added at the top of the form pushed
    // saveTripButton below the default 800x600 test viewport — same fix
    // applied to add_expense_screen_test.dart and
    // exchange_rate_settings_screen_test.dart earlier in this project for
    // the same reason.
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  tearDown(() async => db.close());

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

  testWidgets('create mode: filling valid data creates the trip with one silent participant',
      (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
    await tester.enterText(find.byKey(const Key('tripNameField')), 'Japan Trip');
    await tester.tap(find.byKey(const Key('trackBudgetSwitch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '1000');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final trips = await repo.getAllTrips();
    expect(trips.length, 1);
    expect(trips.first.name, 'Japan Trip');
    expect(trips.first.participants.length, 1);
    expect(trips.first.homeCurrency, 'EUR', reason: 'EUR is the default home currency for a new trip');
  });

  testWidgets('picking a currency from the dropdown saves the trip with that home currency',
      (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
    await tester.enterText(find.byKey(const Key('tripNameField')), 'Alps Trip');
    await tester.tap(find.byKey(const Key('trackBudgetSwitch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '1000');
    await tester.tap(find.byKey(const Key('tripCurrencyField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final trips = await repo.getAllTrips();
    expect(trips.single.homeCurrency, 'EUR');
  });

  testWidgets('leaving budget empty saves the trip with a zero budget', (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
    await tester.enterText(find.byKey(const Key('tripNameField')), 'Backpacking');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final trips = await repo.getAllTrips();
    expect(trips.length, 1);
    expect(trips.first.totalBudget.minorUnits, 0);
  });

  testWidgets('a negative budget is still rejected', (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
    await tester.enterText(find.byKey(const Key('tripNameField')), 'Backpacking');
    await tester.tap(find.byKey(const Key('trackBudgetSwitch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '-5');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    expect(await repo.getAllTrips(), isEmpty);
  });

  testWidgets('empty name shows a validation error and does not save', (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
    await tester.tap(find.byKey(const Key('trackBudgetSwitch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '1000');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a trip name'), findsOneWidget);
    expect(await repo.getAllTrips(), isEmpty);
  });

  testWidgets('edit mode: pre-fills existing fields and updates without touching participants',
      (tester) async {
    final alice = Participant(id: 'p1', name: 'Alice');
    final trip = Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [alice],
    );
    await repo.createTrip(trip);

    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo, existingTrip: trip)));
    expect(find.text('Japan Trip'), findsOneWidget);

    // Structural guard: the currency field must not exist in the widget tree while
    // editing, so there is no way for the user to change the home currency here —
    // currency changes go through ExchangeRateSettingsScreen only.
    expect(find.byKey(const Key('tripCurrencyField')), findsNothing);

    await tester.enterText(find.byKey(const Key('tripNameField')), 'Japan Trip (updated)');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.name, 'Japan Trip (updated)');
    expect(reloaded.participants.map((p) => p.id).toList(), ['p1']);
    expect(reloaded.homeCurrency, 'CNY');
    expect(reloaded.totalBudget.currencyCode, 'CNY');
  });

  testWidgets('the budget switch defaults on when editing a trip that already has a budget, '
      'and the field is visible without tapping anything', (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [Participant(id: 'p1', name: 'Alice')],
    );
    await repo.createTrip(trip);

    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo, existingTrip: trip)));

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('trackBudgetSwitch'))).value, isTrue);
    expect(find.byKey(const Key('tripBudgetField')), findsOneWidget);
  });

  testWidgets('turning off budget tracking for an existing trip clears its budget to zero',
      (tester) async {
    final trip = Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [Participant(id: 'p1', name: 'Alice')],
    );
    await repo.createTrip(trip);

    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo, existingTrip: trip)));
    await tester.tap(find.byKey(const Key('trackBudgetSwitch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tripBudgetField')), findsNothing);

    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.totalBudget.minorUnits, 0);
  });

  // NOTE: this project's `flutter test` environment (Flutter 3.44.7,
  // flutter_tester with software rendering) hangs indefinitely — a genuine
  // native/engine-level deadlock, not a Dart-level timeout that
  // `tester.runAsync()` or a bounded `pump()` count can route around — the
  // instant a widget tree paints a *real, decodable* image via `FileImage`
  // (confirmed with a minimal repro: a bare `CircleAvatar(foregroundImage:
  // FileImage(realJpegOrPngFile))` in an otherwise-empty MaterialApp hangs
  // on its very first pump(), independent of anything in this app's code).
  // So "pick a photo, save it" and "remove an existing photo, save" are
  // deliberately NOT covered by a widget test here — TripPhotoStore's own
  // save/delete/read/write logic is fully covered in
  // test/services/trip_photo_store_test.dart (no widget tree involved,
  // passes fine), and the actual picker interaction was verified manually
  // on the Android emulator instead (see the 2026-07-25 release notes).
  testWidgets('with no stored photo, the picker shows the add-photo icon, not a remove button',
      (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    expect(find.byKey(const Key('removeTripPhotoButton')), findsNothing);
  });
}
