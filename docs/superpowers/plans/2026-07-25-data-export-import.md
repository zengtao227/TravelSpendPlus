# Data Export/Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user back up all trip data to a single JSON file (shared via the OS share sheet) and restore it on a fresh device with zero trips, plus export a single trip's expenses as a CSV table for viewing in a spreadsheet. No CSV import, no merge/overwrite conflict handling — scope confirmed with the user via Telegram Q&A on 2026-07-25 (see `docs/superpowers/specs/2026-07-25-data-export-import-design.md`).

**Architecture:** Pure serialization logic (`domain/backup.dart`) is fully decoupled from file IO and from Flutter — it only converts between domain objects (`Trip`/`Participant`/`Expense`/`ExchangeRate`) and `Map<String, dynamic>`/CSV strings, so it's unit-testable without a widget test harness. `TripRepository` gains two orchestration methods that read/write the database and delegate encoding to `domain/backup.dart` — no schema changes. Actual file writing and the OS share/pick dialogs live in a new `ui/file_io.dart`, injected into the two screens that need them as constructor parameters (default to the real implementation via top-level function tear-offs) so widget tests can substitute fakes instead of touching platform channels.

**Tech Stack:** Existing Flutter/Dart project at `app/`. New dependencies: `share_plus` (OS share sheet), `file_picker` (OS file picker for import), `csv` (correct comma/quote escaping).

## Global Constraints

- **Dates in the JSON backup are plain `"YYYY-MM-DD"` strings, no time, no timezone** — this mirrors `domain/civil_date.dart`'s existing "civil date" convention (added in the previous bug-fix round) precisely so the backup format can't reintroduce the timezone-drift bug that convention was built to eliminate. Every date read from a backup must round-trip through `civilDate()` the same way dates coming out of `TripRepository` already do.
- **Money in the JSON backup is always `minorUnits` (an integer) plus a currency code** — never a floating-point major-unit number, matching `Money`'s own existing internal invariant (`money.dart`'s top comment: "Never store currency amounts as `double`").
- **No CSV import.** CSV is export-only, per the confirmed design scope — do not add a "pick CSV file" path anywhere in this plan.
- **Import is only offered when the device has zero trips.** Do not add merge or overwrite-confirmation UI — this plan deliberately does not handle importing onto a device that already has data.
- **No schema changes.** Both new `TripRepository` methods are built entirely out of its existing methods (`getAllTrips`, `getExpenses`, `getExchangeRates`, `createTrip`, `addExpense`, `setExchangeRate`) — if a task in this plan seems to need a new Drift table or column, stop and re-read the design spec; that would be out of scope.
- **Package versions:** add packages via `flutter pub add <name>` and accept whatever version the resolver picks (matching this project's established practice — see the UI plan's Global Constraints for why). If the resolved `share_plus`/`file_picker` version's API differs from the exact method calls shown in this plan (e.g. `Share.shareXFiles` or `FilePicker.platform.pickFiles` renamed or restructured), check the installed package's own `example/` or public API via `flutter pub deps` and adjust the call site — do not downgrade the package to force the old API.
- Any file importing both `persistence/database.dart` and any of `Trip`/`Participant`/`Expense` must write `import '../persistence/database.dart' hide Trip, Participant, Expense;` (existing project-wide rule, unchanged).
- Widget tests use `AppDatabase.memory()` + a real `TripRepository` — never a mock (existing project-wide rule, unchanged).
- Every screen/widget takes its dependencies as required or defaulted constructor parameters — no `Provider`/DI container (existing project-wide rule, unchanged; the new `shareFile`/`pickJsonFile` params follow this same pattern).

---

### Task 1: `domain/backup.dart` — JSON serialization for a full backup

**Files:**
- Create: `app/lib/domain/backup.dart`
- Test: `app/test/domain/backup_test.dart`

**Interfaces:**
- Produces: `class TripBundle { final Trip trip; final List<Expense> expenses; final List<ExchangeRate> exchangeRates; const TripBundle({required this.trip, required this.expenses, required this.exchangeRates}); }`; `const int kBackupSchemaVersion = 1;`; `class UnsupportedBackupVersionException implements Exception { final int foundVersion; const UnsupportedBackupVersionException(this.foundVersion); }`; `Map<String, dynamic> tripBundleToJson(TripBundle bundle)`; `TripBundle tripBundleFromJson(Map<String, dynamic> json)`; `Map<String, dynamic> backupToJson(List<TripBundle> bundles)`; `List<TripBundle> backupFromJson(Map<String, dynamic> json)`. Task 3 (`TripRepository`) consumes all of these. Task 2 (CSV) shares this file and its date-formatting helpers.

- [ ] **Step 1: Write the failing round-trip test**

```dart
// app/test/domain/backup_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/backup.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';

void main() {
  final alice = const Participant(id: 'p1', name: 'Alice');
  final bob = const Participant(id: 'p2', name: 'Bob');

  Trip makeTrip() => Trip(
        id: 't1',
        name: 'Japan',
        startDate: DateTime.utc(2026, 10, 5),
        endDate: DateTime.utc(2026, 10, 12),
        homeCurrency: 'CNY',
        totalBudget: Money.fromMajor(20000, 'CNY'),
        participants: [alice, bob],
      );

  Expense makeExpense() => Expense(
        id: 'e1',
        tripId: 't1',
        category: 'food',
        amount: Money.fromMajor(10000, 'JPY'),
        amountInHomeCurrency: Money.fromMajor(500, 'CNY'),
        description: 'Dinner, with a comma',
        date: DateTime.utc(2026, 10, 6),
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice, bob],
      );

  test('tripBundleToJson then tripBundleFromJson round-trips a trip with an expense and a rate',
      () {
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: [makeExpense()],
      exchangeRates: const [ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05)],
    );

    final restored = tripBundleFromJson(tripBundleToJson(bundle));

    expect(restored.trip.id, 't1');
    expect(restored.trip.name, 'Japan');
    expect(restored.trip.startDate, DateTime.utc(2026, 10, 5));
    expect(restored.trip.endDate, DateTime.utc(2026, 10, 12));
    expect(restored.trip.homeCurrency, 'CNY');
    expect(restored.trip.totalBudget, Money.fromMajor(20000, 'CNY'));
    expect(restored.trip.participants.map((p) => p.id).toSet(), {'p1', 'p2'});

    expect(restored.expenses, hasLength(1));
    final e = restored.expenses.single;
    expect(e.id, 'e1');
    expect(e.category, 'food');
    expect(e.amount, Money.fromMajor(10000, 'JPY'));
    expect(e.amountInHomeCurrency, Money.fromMajor(500, 'CNY'));
    expect(e.description, 'Dinner, with a comma');
    expect(e.date, DateTime.utc(2026, 10, 6));
    expect(e.status, ExpenseStatus.actual);
    expect(e.paidBy.id, 'p1');
    expect(e.paidFor.map((p) => p.id).toSet(), {'p1', 'p2'});

    expect(restored.exchangeRates, hasLength(1));
    expect(restored.exchangeRates.single.fromCurrency, 'JPY');
    expect(restored.exchangeRates.single.toCurrency, 'CNY');
    expect(restored.exchangeRates.single.rate, 0.05);
  });

  test('a planned expense and a whole-number exchange rate round-trip correctly '
      '(JSON decodes whole numbers as int, not double — the rate parser must handle both)',
      () {
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: [
        makeExpense().copyWith(status: ExpenseStatus.planned, includeInSplit: false),
      ],
      exchangeRates: const [ExchangeRate(fromCurrency: 'USD', toCurrency: 'CNY', rate: 7)],
    );

    final restored = tripBundleFromJson(tripBundleToJson(bundle));

    expect(restored.expenses.single.status, ExpenseStatus.planned);
    expect(restored.expenses.single.includeInSplit, isFalse);
    expect(restored.exchangeRates.single.rate, 7.0);
  });

  test('backupToJson wraps trips with a schemaVersion and backupFromJson unwraps them', () {
    final bundle = TripBundle(trip: makeTrip(), expenses: [], exchangeRates: const []);

    final json = backupToJson([bundle]);
    expect(json['schemaVersion'], kBackupSchemaVersion);
    expect(json['trips'], hasLength(1));

    final restored = backupFromJson(json);
    expect(restored, hasLength(1));
    expect(restored.single.trip.id, 't1');
  });

  test('backupFromJson rejects a schemaVersion newer than this app understands', () {
    final json = {
      'schemaVersion': kBackupSchemaVersion + 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'trips': <Map<String, dynamic>>[],
    };
    expect(() => backupFromJson(json), throwsA(isA<UnsupportedBackupVersionException>()));
  });

  test('an empty trip (no expenses, no rates) round-trips fine', () {
    final bundle = TripBundle(trip: makeTrip(), expenses: [], exchangeRates: const []);
    final restored = tripBundleFromJson(tripBundleToJson(bundle));
    expect(restored.expenses, isEmpty);
    expect(restored.exchangeRates, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && flutter test test/domain/backup_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/domain/backup.dart': No such file or directory` (the file doesn't exist yet).

- [ ] **Step 3: Write `domain/backup.dart`**

```dart
// app/lib/domain/backup.dart
import 'civil_date.dart';
import 'exchange_rate.dart';
import 'expense.dart';
import 'money.dart';
import 'participant.dart';
import 'trip.dart';

/// Bumped whenever `tripBundleToJson`'s output shape changes in a way an
/// older app version couldn't parse. `backupFromJson` refuses to read a
/// backup with a higher version than this app understands (see
/// [UnsupportedBackupVersionException]) rather than guessing.
const int kBackupSchemaVersion = 1;

class UnsupportedBackupVersionException implements Exception {
  final int foundVersion;
  const UnsupportedBackupVersionException(this.foundVersion);

  @override
  String toString() =>
      'This backup was made with a newer app version (schemaVersion $foundVersion); '
      'this app only understands up to $kBackupSchemaVersion.';
}

/// Everything needed to fully restore one trip: the trip itself (which
/// already carries its own `participants`), its expenses, and its manual
/// exchange-rate table — exactly what `TripRepository` needs three separate
/// queries to assemble (see `TripRepository.exportAllTripsToJson`).
class TripBundle {
  final Trip trip;
  final List<Expense> expenses;
  final List<ExchangeRate> exchangeRates;
  const TripBundle({required this.trip, required this.expenses, required this.exchangeRates});
}

/// Formats as `"YYYY-MM-DD"` — a plain civil date, no time, no timezone.
/// Matches `civil_date.dart`'s convention deliberately: this is the same
/// "calendar day, not an instant" representation the rest of the app uses,
/// so a backup file can't reintroduce the timezone-drift bug that file was
/// written to eliminate.
String dateToBackupString(DateTime date) {
  final c = civilDate(date);
  final y = c.year.toString().padLeft(4, '0');
  final m = c.month.toString().padLeft(2, '0');
  final d = c.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime dateFromBackupString(String s) {
  final parts = s.split('-');
  return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

Map<String, dynamic> tripBundleToJson(TripBundle bundle) {
  final trip = bundle.trip;
  return {
    'id': trip.id,
    'name': trip.name,
    'startDate': dateToBackupString(trip.startDate),
    'endDate': dateToBackupString(trip.endDate),
    'homeCurrency': trip.homeCurrency,
    'totalBudgetMinorUnits': trip.totalBudget.minorUnits,
    'participants': trip.participants.map((p) => {'id': p.id, 'name': p.name}).toList(),
    'expenses': bundle.expenses
        .map((e) => {
              'id': e.id,
              'category': e.category,
              'amountMinorUnits': e.amount.minorUnits,
              'amountCurrency': e.amount.currencyCode,
              'amountInHomeCurrencyMinorUnits': e.amountInHomeCurrency.minorUnits,
              'description': e.description,
              'date': dateToBackupString(e.date),
              'status': e.status == ExpenseStatus.actual ? 'actual' : 'planned',
              'includeInSplit': e.includeInSplit,
              'paidById': e.paidBy.id,
              'paidForIds': e.paidFor.map((p) => p.id).toList(),
            })
        .toList(),
    'exchangeRates':
        bundle.exchangeRates.map((r) => {'fromCurrency': r.fromCurrency, 'rate': r.rate}).toList(),
  };
}

TripBundle tripBundleFromJson(Map<String, dynamic> json) {
  final participantsById = <String, Participant>{
    for (final raw in (json['participants'] as List).cast<Map<String, dynamic>>())
      raw['id'] as String: Participant(id: raw['id'] as String, name: raw['name'] as String),
  };
  final homeCurrency = json['homeCurrency'] as String;

  final trip = Trip(
    id: json['id'] as String,
    name: json['name'] as String,
    startDate: dateFromBackupString(json['startDate'] as String),
    endDate: dateFromBackupString(json['endDate'] as String),
    homeCurrency: homeCurrency,
    totalBudget:
        Money(minorUnits: json['totalBudgetMinorUnits'] as int, currencyCode: homeCurrency),
    participants: participantsById.values.toList(),
  );

  final expenses = (json['expenses'] as List).cast<Map<String, dynamic>>().map((raw) {
    final paidForIds = (raw['paidForIds'] as List).cast<String>();
    return Expense(
      id: raw['id'] as String,
      tripId: trip.id,
      category: raw['category'] as String,
      amount: Money(
        minorUnits: raw['amountMinorUnits'] as int,
        currencyCode: raw['amountCurrency'] as String,
      ),
      amountInHomeCurrency: Money(
        minorUnits: raw['amountInHomeCurrencyMinorUnits'] as int,
        currencyCode: homeCurrency,
      ),
      description: raw['description'] as String,
      date: dateFromBackupString(raw['date'] as String),
      status: raw['status'] == 'actual' ? ExpenseStatus.actual : ExpenseStatus.planned,
      includeInSplit: raw['includeInSplit'] as bool,
      paidBy: participantsById[raw['paidById'] as String]!,
      paidFor: paidForIds.map((id) => participantsById[id]!).toList(),
    );
  }).toList();

  final exchangeRates = (json['exchangeRates'] as List).cast<Map<String, dynamic>>().map((raw) {
    // JSON decodes a whole-number rate (e.g. `7`) as int, not double —
    // `num.toDouble()` handles both.
    return ExchangeRate(
      fromCurrency: raw['fromCurrency'] as String,
      toCurrency: homeCurrency,
      rate: (raw['rate'] as num).toDouble(),
    );
  }).toList();

  return TripBundle(trip: trip, expenses: expenses, exchangeRates: exchangeRates);
}

Map<String, dynamic> backupToJson(List<TripBundle> bundles) => {
      'schemaVersion': kBackupSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'trips': bundles.map(tripBundleToJson).toList(),
    };

List<TripBundle> backupFromJson(Map<String, dynamic> json) {
  final version = json['schemaVersion'] as int?;
  if (version == null || version > kBackupSchemaVersion) {
    throw UnsupportedBackupVersionException(version ?? 0);
  }
  return (json['trips'] as List).cast<Map<String, dynamic>>().map(tripBundleFromJson).toList();
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd app && flutter test test/domain/backup_test.dart
```

Expected: `All tests passed!` (5 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/domain/backup.dart app/test/domain/backup_test.dart
git commit -m "Add JSON serialization for full trip backups"
```

---

### Task 2: `domain/backup.dart` — CSV export for one trip's expenses

**Files:**
- Modify: `app/lib/domain/backup.dart`
- Modify: `app/pubspec.yaml` (add `csv` dependency)
- Test: `app/test/domain/backup_test.dart`

**Interfaces:**
- Consumes: `dateToBackupString` (Task 1, same file).
- Produces: `String expensesToCsv(List<Expense> expenses, {required List<String> headers, required String Function(String categoryKey) categoryLabel, required String Function(ExpenseStatus status) statusLabel})`. Task 6 (`TripDetailScreen`) consumes this, supplying localized `headers`/`categoryLabel`/`statusLabel`.

- [ ] **Step 1: Add the `csv` package**

```bash
cd app && flutter pub add csv
```

Expected: exit 0; `csv` appears under `dependencies:` in `app/pubspec.yaml`.

- [ ] **Step 2: Write the failing test**

Append to `app/test/domain/backup_test.dart` (add this import at the top alongside the others: `import 'package:travelspendplus/domain/expense_category.dart';` is not needed — categories are passed as plain strings in this test):

```dart
  group('expensesToCsv', () {
    final alice = const Participant(id: 'p1', name: 'Alice');

    Expense expenseWith({required String description, required double amountMajor}) => Expense(
          id: 'e-$description',
          tripId: 't1',
          category: 'food',
          amount: Money.fromMajor(amountMajor, 'JPY'),
          amountInHomeCurrency: Money.fromMajor(amountMajor * 0.05, 'CNY'),
          description: description,
          date: DateTime.utc(2026, 10, 6),
          status: ExpenseStatus.actual,
          includeInSplit: true,
          paidBy: alice,
          paidFor: [alice],
        );

    String label(String key) => key == 'food' ? 'Food' : key;
    String status(ExpenseStatus s) => s == ExpenseStatus.actual ? 'Actual' : 'Planned';
    const headers = ['Date', 'Category', 'Status', 'Description', 'Amount', 'Currency', 'In CNY'];

    test('produces a header row plus one row per expense', () {
      final csv = expensesToCsv(
        [expenseWith(description: 'Ramen', amountMajor: 1000)],
        headers: headers,
        categoryLabel: label,
        statusLabel: status,
      );
      final lines = csv.trim().split('\r\n');
      expect(lines, hasLength(2));
      expect(lines[0], 'Date,Category,Status,Description,Amount,Currency,In CNY');
      expect(lines[1], '2026-10-06,Food,Actual,Ramen,1000.00,JPY,50.00');
    });

    test('escapes a description containing a comma', () {
      final csv = expensesToCsv(
        [expenseWith(description: 'Ramen, extra egg', amountMajor: 1000)],
        headers: headers,
        categoryLabel: label,
        statusLabel: status,
      );
      expect(csv, contains('"Ramen, extra egg"'));
    });

    test('an empty expense list produces just the header row', () {
      final csv = expensesToCsv([], headers: headers, categoryLabel: label, statusLabel: status);
      expect(csv.trim().split('\r\n'), hasLength(1));
    });
  });
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd app && flutter test test/domain/backup_test.dart
```

Expected: FAIL — `expensesToCsv` is not defined.

- [ ] **Step 4: Add `expensesToCsv` to `domain/backup.dart`**

Add this import at the top of `app/lib/domain/backup.dart`, alongside the existing ones:

```dart
import 'package:csv/csv.dart';
```

Add this function at the end of the file:

```dart
/// One row per expense, in the exact order given (callers typically pass
/// `TripRepository.getExpenses`'s own order). [headers], [categoryLabel],
/// and [statusLabel] are supplied by the caller because they're localized
/// display text — this file has no dependency on Flutter/`AppLocalizations`
/// so it stays unit-testable without a widget test harness.
String expensesToCsv(
  List<Expense> expenses, {
  required List<String> headers,
  required String Function(String categoryKey) categoryLabel,
  required String Function(ExpenseStatus status) statusLabel,
}) {
  final rows = <List<String>>[headers];
  for (final e in expenses) {
    rows.add([
      dateToBackupString(e.date),
      categoryLabel(e.category),
      statusLabel(e.status),
      e.description,
      e.amount.major.toStringAsFixed(2),
      e.amount.currencyCode,
      e.amountInHomeCurrency.major.toStringAsFixed(2),
    ]);
  }
  return const ListToCsvConverter().convert(rows);
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd app && flutter test test/domain/backup_test.dart
```

Expected: `All tests passed!` (8 tests total: 5 from Task 1 + 3 new).

- [ ] **Step 6: Commit**

```bash
git add app/lib/domain/backup.dart app/test/domain/backup_test.dart app/pubspec.yaml app/pubspec.lock
git commit -m "Add CSV export for a single trip's expenses"
```

---

### Task 3: `TripRepository` — export/import orchestration

**Files:**
- Modify: `app/lib/persistence/trip_repository.dart`
- Test: `app/test/persistence/trip_repository_test.dart`

**Interfaces:**
- Consumes: `TripBundle`, `backupToJson`, `backupFromJson` (Task 1); existing `TripRepository` methods (`getAllTrips`, `getExpenses`, `getExchangeRates`, `createTrip`, `addExpense`, `setExchangeRate`).
- Produces: `Future<Map<String, dynamic>> TripRepository.exportAllTripsToJson()`; `Future<int> TripRepository.importAllTripsFromJson(Map<String, dynamic> json)` (returns the number of trips imported, for the UI's success message). Task 5 (`TripListScreen`) consumes both.

- [ ] **Step 1: Write the failing tests**

Add to `app/test/persistence/trip_repository_test.dart`. First add this import at the top, alongside the existing ones:

```dart
import 'package:travelspendplus/domain/backup.dart';
```

Then add this group at the end of `main()`, before the closing `}`:

```dart
  group('export/import', () {
    test('exportAllTripsToJson then importAllTripsFromJson (into a fresh db) round-trips '
        'a trip with an expense and a rate', () async {
      final trip = makeTrip(); // existing helper in this file
      await repo.createTrip(trip);
      await repo.setExchangeRate(
          trip.id, const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.006));
      await repo.addExpense(Expense(
        id: 'e1',
        tripId: trip.id,
        category: 'food',
        amount: Money.fromMajor(1000, 'JPY'),
        amountInHomeCurrency: Money.fromMajor(6, 'EUR'),
        description: 'Ramen',
        date: DateTime(2026, 1, 2),
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice],
      ));

      final json = await repo.exportAllTripsToJson();

      final freshDb = AppDatabase.memory();
      final freshRepo = TripRepository(freshDb);
      final importedCount = await freshRepo.importAllTripsFromJson(json);
      expect(importedCount, 1);

      final restoredTrip = await freshRepo.getTrip(trip.id);
      expect(restoredTrip, isNotNull);
      expect(restoredTrip!.name, trip.name);
      final restoredExpenses = await freshRepo.getExpenses(trip.id);
      expect(restoredExpenses, hasLength(1));
      expect(restoredExpenses.single.description, 'Ramen');
      final restoredRates = await freshRepo.getExchangeRates(trip.id);
      expect(restoredRates, hasLength(1));
      expect(restoredRates.single.fromCurrency, 'JPY');

      await freshDb.close();
    });

    test('exportAllTripsToJson with zero trips produces an empty trips list', () async {
      final json = await repo.exportAllTripsToJson();
      expect(json['trips'], isEmpty);
    });

    test('importAllTripsFromJson rejects a backup with a newer schemaVersion', () async {
      final json = {
        'schemaVersion': kBackupSchemaVersion + 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'trips': <Map<String, dynamic>>[],
      };
      expect(
        () => repo.importAllTripsFromJson(json),
        throwsA(isA<UnsupportedBackupVersionException>()),
      );
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd app && flutter test test/persistence/trip_repository_test.dart
```

Expected: FAIL — `exportAllTripsToJson`/`importAllTripsFromJson` are not defined on `TripRepository`.

- [ ] **Step 3: Add the two methods to `TripRepository`**

Add this import at the top of `app/lib/persistence/trip_repository.dart`, alongside the existing ones:

```dart
import '../domain/backup.dart';
```

Add these two methods at the end of the `TripRepository` class, just before its closing `}`:

```dart
  /// Assembles every trip currently in the database (with its expenses and
  /// exchange rates) into one JSON-serializable backup. Pure data assembly —
  /// nothing here writes to disk or touches the OS share sheet; that's the
  /// UI layer's job (`ui/file_io.dart`).
  Future<Map<String, dynamic>> exportAllTripsToJson() async {
    final trips = await getAllTrips();
    final bundles = <TripBundle>[];
    for (final trip in trips) {
      bundles.add(TripBundle(
        trip: trip,
        expenses: await getExpenses(trip.id),
        exchangeRates: await getExchangeRates(trip.id),
      ));
    }
    return backupToJson(bundles);
  }

  /// Restores every trip in [json] into the database via the same
  /// `createTrip`/`addExpense`/`setExchangeRate` calls any other code path
  /// uses — callers are responsible for only invoking this on an empty
  /// database (see the design spec: this app doesn't support merging a
  /// backup into existing data). Returns the number of trips imported, for
  /// a UI success message.
  Future<int> importAllTripsFromJson(Map<String, dynamic> json) async {
    final bundles = backupFromJson(json); // throws UnsupportedBackupVersionException if too new
    for (final bundle in bundles) {
      await createTrip(bundle.trip);
      for (final rate in bundle.exchangeRates) {
        await setExchangeRate(bundle.trip.id, rate);
      }
      for (final expense in bundle.expenses) {
        await addExpense(expense);
      }
    }
    return bundles.length;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd app && flutter test test/persistence/trip_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Run the full test suite to check for regressions**

```bash
cd app && flutter test
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add app/lib/persistence/trip_repository.dart app/test/persistence/trip_repository_test.dart
git commit -m "Add TripRepository.exportAllTripsToJson/importAllTripsFromJson"
```

---

### Task 4: `ui/file_io.dart` — file writing, sharing, and picking

**Files:**
- Create: `app/lib/ui/file_io.dart`
- Modify: `app/pubspec.yaml` (add `share_plus`, `file_picker`)

**Interfaces:**
- Produces: `Future<String> writeTempFile(String filename, String content)`; `Future<void> shareFile(String path, {String? subject})`; `Future<String?> pickJsonFile()` — this one both picks *and reads* the file, returning its text content (not just a path), specifically so Task 5's widget tests can fake "the user picked a backup" by returning a JSON string directly, without touching the real filesystem. Tasks 5 and 6 consume these (as default constructor-parameter values via tear-off, and directly).

No dedicated unit test for this file — per the design spec, the OS share sheet and file picker are platform-native UI this project doesn't attempt to test directly (Tasks 5/6 verify the screens' *logic* by injecting fakes for these three functions instead). `flutter analyze` staying clean is this task's correctness check.

- [ ] **Step 1: Add the packages**

```bash
cd app && flutter pub add share_plus file_picker
```

Expected: exit 0; both appear under `dependencies:` in `app/pubspec.yaml`.

- [ ] **Step 2: Write `ui/file_io.dart`**

```dart
// app/lib/ui/file_io.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [content] to a file named [filename] in the app's temp directory
/// and returns its full path — the file this returns is what gets handed to
/// [shareFile] (the OS share sheet needs a real file on disk, not a string).
Future<String> writeTempFile(String filename, String content) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsString(content);
  return file.path;
}

/// Opens the OS share sheet for the file at [path] (Files app, Drive,
/// messaging apps, etc. — whatever the user picks). This is the standard
/// Flutter pattern for "export a file" that avoids requesting storage
/// permissions (see the design spec's technical-approach comparison).
Future<void> shareFile(String path, {String? subject}) async {
  await Share.shareXFiles([XFile(path)], subject: subject);
}

/// Opens the OS file picker restricted to `.json` files and returns the
/// picked file's *content* (not just its path — the only thing any caller
/// in this app ever does with the path is immediately read it), or `null`
/// if the user cancelled.
Future<String?> pickJsonFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (result == null || result.files.isEmpty) return null;
  final path = result.files.single.path;
  if (path == null) return null;
  return File(path).readAsString();
}
```

- [ ] **Step 3: Verify it compiles cleanly**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`. If `Share.shareXFiles` or `FilePicker.platform.pickFiles` doesn't resolve, check the installed package version's actual API (see this plan's Global Constraints) and adjust — do not skip this step or leave a compile error for a later task to discover.

- [ ] **Step 4: Commit**

```bash
git add app/lib/ui/file_io.dart app/pubspec.yaml app/pubspec.lock
git commit -m "Add file_io.dart: temp-file writing, OS share sheet, OS file picker"
```

---

### Task 5: `TripListScreen` — full backup export + restore-on-empty-device import

**Files:**
- Modify: `app/lib/ui/trip_list_screen.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_zh.arb`, `app/lib/l10n/app_de.arb`
- Test: `app/test/ui/trip_list_screen_test.dart`

**Interfaces:**
- Consumes: `TripRepository.exportAllTripsToJson`/`importAllTripsFromJson` (Task 3); `writeTempFile`/`shareFile`/`pickJsonFile` (Task 4).
- Produces: `TripListScreen` gains three optional constructor parameters — `Future<String> Function(String, String) writeTempFile`, `Future<void> Function(String, {String? subject}) shareFile`, `Future<String?> Function() pickJsonFile` — each defaulting to the real `ui/file_io.dart` functions via tear-off, so widget tests can override them with fakes.

- [ ] **Step 1: Add the ARB strings**

Add to `app/lib/l10n/app_en.arb` (insert after `"spentTotal": "Spent"`, before the closing `}`, remembering to add a comma after the previous line):

```json
  "spentTotal": "Spent",
  "backupAll": "Full backup",
  "restoreFromBackup": "Restore from backup",
  "importSuccess": "{count, plural, =1{Restored 1 trip} other{Restored {count} trips}}",
  "@importSuccess": {"placeholders": {"count": {"type": "int"}}},
  "errorImportParseFailed": "This file couldn't be read as a TravelSpendPlus backup",
  "errorImportUnsupportedVersion": "This backup was created by a newer version of the app — please update first",
  "errorExportFailed": "Export failed — please try again"
```

Add to `app/lib/l10n/app_zh.arb` (insert after `"spentTotal": "已花费"`):

```json
  "spentTotal": "已花费",
  "backupAll": "完整备份",
  "restoreFromBackup": "从备份恢复",
  "importSuccess": "已恢复 {count} 个行程",
  "errorImportParseFailed": "备份文件无法读取，请确认选择的是本 App 导出的备份文件",
  "errorImportUnsupportedVersion": "这个备份文件是更新版本的 App 导出的，请先升级 App",
  "errorExportFailed": "导出失败，请重试"
```

Add to `app/lib/l10n/app_de.arb` (insert after `"spentTotal": "Ausgegeben"`, which is currently the last key before the file's closing `}` — add a comma after it):

```json
  "backupAll": "Vollständiges Backup",
  "restoreFromBackup": "Aus Backup wiederherstellen",
  "importSuccess": "{count, plural, =1{1 Reise wiederhergestellt} other{{count} Reisen wiederhergestellt}}",
  "@importSuccess": {"placeholders": {"count": {"type": "int"}}},
  "errorImportParseFailed": "Diese Datei konnte nicht als TravelSpendPlus-Backup gelesen werden",
  "errorImportUnsupportedVersion": "Dieses Backup wurde mit einer neueren App-Version erstellt — bitte zuerst aktualisieren",
  "errorExportFailed": "Export fehlgeschlagen — bitte erneut versuchen"
```

Regenerate:

```bash
cd app && flutter gen-l10n
```

Expected: no errors.

- [ ] **Step 2: Write the failing widget tests**

Add these imports to the top of `app/test/ui/trip_list_screen_test.dart`, alongside the existing ones:

```dart
import 'dart:convert';
import 'package:travelspendplus/domain/backup.dart';
```

Change the `wrap()` helper to accept the three injectable functions (replace the existing `wrap()` definition):

```dart
  Widget wrap({
    Future<String> Function(String, String)? writeTempFile,
    Future<void> Function(String, {String? subject})? shareFile,
    Future<String?> Function()? pickJsonFile,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripListScreen(
          repository: repo,
          writeTempFile: writeTempFile ?? (name, content) async => '/tmp/$name',
          shareFile: shareFile ?? (path, {subject}) async {},
          pickJsonFile: pickJsonFile ?? () async => null,
        ),
      );
```

Add these tests at the end of `main()`, before the closing `}`:

```dart
  testWidgets('tapping the backup button shares a JSON file containing the exported data',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    String? sharedPath;
    Map<String, dynamic>? writtenContent;
    await tester.pumpWidget(wrap(
      writeTempFile: (name, content) async {
        writtenContent = jsonDecode(content) as Map<String, dynamic>;
        return '/tmp/$name';
      },
      shareFile: (path, {subject}) async => sharedPath = path,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backupAllButton')));
    await tester.pumpAndSettle();

    expect(sharedPath, isNotNull);
    expect(writtenContent, isNotNull);
    expect(writtenContent!['trips'], hasLength(1));
    expect((writtenContent!['trips'] as List).first, containsPair('name', 'Japan Trip'));
  });

  testWidgets('the empty state offers a restore-from-backup button that imports the picked backup',
      (tester) async {
    final backupJson = backupToJson([
      TripBundle(
        trip: Trip(
          id: 't1',
          name: 'Restored Trip',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 5),
          homeCurrency: 'EUR',
          totalBudget: Money.fromMajor(1000, 'EUR'),
          participants: [me],
        ),
        expenses: const [],
        exchangeRates: const [],
      ),
    ]);

    // pickJsonFile returns the file's *content* (see Task 4), so this fake
    // can hand back a fabricated backup string directly — no real
    // filesystem access needed to exercise the full real import path
    // (jsonDecode -> TripRepository.importAllTripsFromJson -> the real
    // in-memory database).
    await tester.pumpWidget(wrap(pickJsonFile: () async => jsonEncode(backupJson)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('restoreFromBackupButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('restoreFromBackupButton')));
    await tester.pumpAndSettle();

    // The empty state is gone and the restored trip's own card is showing —
    // proof the button actually drove a real import, not just that it exists.
    expect(find.text('Restored Trip'), findsOneWidget);
  });

  testWidgets('a failed import shows an error message instead of failing silently',
      (tester) async {
    await tester.pumpWidget(wrap(pickJsonFile: () async => 'not valid json{{{'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('restoreFromBackupButton')));
    await tester.pumpAndSettle();

    expect(find.text('This file couldn\'t be read as a TravelSpendPlus backup'), findsOneWidget);
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
cd app && flutter test test/ui/trip_list_screen_test.dart
```

Expected: FAIL — `TripListScreen` doesn't accept `writeTempFile`/`shareFile`/`pickJsonFile` yet, and `Key('backupAllButton')`/`Key('restoreFromBackupButton')` don't exist.

- [ ] **Step 4: Wire the buttons into `TripListScreen`**

Replace the full contents of `app/lib/ui/trip_list_screen.dart`'s imports and `_TripListScreenState` class (keep `_TripCard` and everything below it unchanged):

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/backup.dart';
import '../domain/budget_calculator.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'create_trip_screen.dart';
import 'file_io.dart' as file_io;
import 'formatting.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  final TripRepository repository;
  final Future<String> Function(String filename, String content) writeTempFile;
  final Future<void> Function(String path, {String? subject}) shareFile;
  final Future<String?> Function() pickJsonFile;

  const TripListScreen({
    super.key,
    required this.repository,
    this.writeTempFile = file_io.writeTempFile,
    this.shareFile = file_io.shareFile,
    this.pickJsonFile = file_io.pickJsonFile,
  });

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  late Future<List<Trip>> _future;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getAllTrips();
  }

  void _refresh() => setState(() {
        _future = widget.repository.getAllTrips();
      });

  Future<void> _exportAll() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final json = await widget.repository.exportAllTripsToJson();
      final content = const JsonEncoder.withIndent('  ').convert(json);
      final path = await widget.writeTempFile(
        'travelspendplus_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        content,
      );
      await widget.shareFile(path, subject: l10n.backupAll);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorExportFailed)));
    }
  }

  Future<void> _importAll() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _importError = null);
    final content = await widget.pickJsonFile(); // returns file content, not a path — see file_io.dart
    if (content == null) return; // user cancelled
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final count = await widget.repository.importAllTripsFromJson(json);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importSuccess(count))));
      _refresh();
    } on UnsupportedBackupVersionException {
      if (!mounted) return;
      setState(() => _importError = l10n.errorImportUnsupportedVersion);
    } catch (_) {
      if (!mounted) return;
      setState(() => _importError = l10n.errorImportParseFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myTrips),
        actions: [
          IconButton(
            key: const Key('backupAllButton'),
            icon: const Icon(Icons.backup),
            tooltip: l10n.backupAll,
            onPressed: _exportAll,
          ),
        ],
      ),
      body: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.noTripsYet, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      key: const Key('restoreFromBackupButton'),
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.restoreFromBackup),
                      onPressed: _importAll,
                    ),
                    if (_importError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_importError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              return _TripCard(
                trip: trips[index],
                repository: widget.repository,
                onReturned: _refresh,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => CreateTripScreen(repository: widget.repository)));
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd app && flutter test test/ui/trip_list_screen_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Run `flutter analyze`**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/trip_list_screen.dart app/lib/l10n/ app/test/ui/trip_list_screen_test.dart
git commit -m "Add full-backup export and restore-from-backup import to TripListScreen"
```

---

### Task 6: `TripDetailScreen` — per-trip CSV export

**Files:**
- Modify: `app/lib/ui/trip_detail_screen.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_zh.arb`, `app/lib/l10n/app_de.arb`
- Test: `app/test/ui/trip_detail_screen_test.dart`

**Interfaces:**
- Consumes: `expensesToCsv` (Task 2); `writeTempFile`/`shareFile` (Task 4); `categoryLabel` (existing, `ui/formatting.dart`).
- Produces: `TripDetailScreen` gains two optional constructor parameters — `Future<String> Function(String, String) writeTempFile`, `Future<void> Function(String, {String? subject}) shareFile` — same injection pattern as Task 5.

- [ ] **Step 1: Add the ARB strings**

Add to `app/lib/l10n/app_en.arb` (insert after `"errorExportFailed": "Export failed — please try again"` from Task 5, remembering the comma):

```json
  "exportTripCsv": "Export as CSV",
  "csvHeaderDate": "Date",
  "csvHeaderCategory": "Category",
  "csvHeaderStatus": "Status",
  "csvHeaderDescription": "Description",
  "csvHeaderAmount": "Amount",
  "csvHeaderCurrency": "Currency",
  "csvHeaderAmountInHomeCurrency": "Amount (home currency)"
```

Add to `app/lib/l10n/app_zh.arb`:

```json
  "exportTripCsv": "导出为表格",
  "csvHeaderDate": "日期",
  "csvHeaderCategory": "类别",
  "csvHeaderStatus": "状态",
  "csvHeaderDescription": "备注",
  "csvHeaderAmount": "金额",
  "csvHeaderCurrency": "币种",
  "csvHeaderAmountInHomeCurrency": "折合本位币金额"
```

Add to `app/lib/l10n/app_de.arb`:

```json
  "exportTripCsv": "Als CSV exportieren",
  "csvHeaderDate": "Datum",
  "csvHeaderCategory": "Kategorie",
  "csvHeaderStatus": "Status",
  "csvHeaderDescription": "Beschreibung",
  "csvHeaderAmount": "Betrag",
  "csvHeaderCurrency": "Währung",
  "csvHeaderAmountInHomeCurrency": "Betrag (Heimatwährung)"
```

Regenerate:

```bash
cd app && flutter gen-l10n
```

Expected: no errors.

- [ ] **Step 2: Write the failing widget test**

Add this import to `app/test/ui/trip_detail_screen_test.dart`, alongside the existing ones:

```dart
import 'dart:convert';
```

This file's existing `wrap()` helper (confirmed current content, `app/test/ui/trip_detail_screen_test.dart:28-33`) is:

```dart
  Widget wrap(String tripId) => MaterialApp(
        locale: const Locale('zh'), // tests tap/assert Chinese labels below; pin the locale explicitly
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripDetailScreen(tripId: tripId, repository: repo),
      );
```

Replace it with:

```dart
  Widget wrap(
    String tripId, {
    Future<String> Function(String, String)? writeTempFile,
    Future<void> Function(String, {String? subject})? shareFile,
  }) =>
      MaterialApp(
        locale: const Locale('zh'), // tests tap/assert Chinese labels below; pin the locale explicitly
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripDetailScreen(
          tripId: tripId,
          repository: repo,
          writeTempFile: writeTempFile ?? (name, content) async => '/tmp/$name',
          shareFile: shareFile ?? (path, {subject}) async {},
        ),
      );
```

Add this test at the end of `main()`, before the closing `}`:

```dart
  testWidgets('the CSV export button shares a file containing one row per expense',
      (tester) async {
    final me = const Participant(id: 'p1', name: 'Me');
    final trip = Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    );
    await repo.createTrip(trip);
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Dinner',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    String? writtenContent;
    await tester.pumpWidget(wrap(
      't1',
      writeTempFile: (name, content) async {
        writtenContent = content;
        return '/tmp/$name';
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('exportTripCsvButton')));
    await tester.pumpAndSettle();

    expect(writtenContent, isNotNull);
    expect(writtenContent, contains('Dinner'));
    expect(writtenContent, contains('2026-10-06'));
  });
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd app && flutter test test/ui/trip_detail_screen_test.dart
```

Expected: FAIL — `TripDetailScreen` doesn't accept `writeTempFile`/`shareFile` yet, and `Key('exportTripCsvButton')` doesn't exist.

- [ ] **Step 4: Wire the button into `TripDetailScreen`**

Add these imports to `app/lib/ui/trip_detail_screen.dart`, alongside the existing ones:

```dart
import '../domain/backup.dart';
import 'file_io.dart' as file_io;
```

Change the `TripDetailScreen` class declaration to add the two new fields (replace the existing class header down through its constructor):

```dart
class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final TripRepository repository;
  final Future<String> Function(String filename, String content) writeTempFile;
  final Future<void> Function(String path, {String? subject}) shareFile;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    required this.repository,
    this.writeTempFile = file_io.writeTempFile,
    this.shareFile = file_io.shareFile,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}
```

Add this method to `_TripDetailScreenState`, near `_markAsSpent` (uses `_TripDetailData` from the currently-loaded `_future`, so it needs the same data the build method already has — read it via `_future`'s last value the way the export flow needs to, by taking the already-loaded `_TripDetailData` as a parameter from the call site instead of re-awaiting `_future` itself):

```dart
  Future<void> _exportCsv(Trip trip, List<Expense> expenses) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final csv = expensesToCsv(
        expenses,
        headers: [
          l10n.csvHeaderDate,
          l10n.csvHeaderCategory,
          l10n.csvHeaderStatus,
          l10n.csvHeaderDescription,
          l10n.csvHeaderAmount,
          l10n.csvHeaderCurrency,
          l10n.csvHeaderAmountInHomeCurrency,
        ],
        categoryLabel: (key) => categoryLabel(context, key),
        statusLabel: (status) => status == ExpenseStatus.actual ? l10n.statusActual : l10n.statusPlanned,
      );
      final safeName = trip.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = await widget.writeTempFile('${safeName}_expenses.csv', csv);
      await widget.shareFile(path, subject: trip.name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorExportFailed)));
    }
  }
```

In the `build` method, find the `actions:` list inside the `AppBar` (the `Row` containing the edit and currency-exchange `IconButton`s) and add a third `IconButton` after the currency-exchange one, still inside the same `Row(children: [...])`:

```dart
                IconButton(
                  key: const Key('exportTripCsvButton'),
                  icon: const Icon(Icons.ios_share),
                  tooltip: l10n.exportTripCsv,
                  onPressed: () => _exportCsv(trip, snapshot.data!.expenses),
                ),
```

(This sits inside the existing `FutureBuilder<_TripDetailData>` builder in the `actions:` list, where `trip` is already in scope as `snapshot.data!.trip` — use `snapshot.data!.expenses` for the second argument as shown.)

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd app && flutter test test/ui/trip_detail_screen_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Run `flutter analyze`**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/trip_detail_screen.dart app/lib/l10n/ app/test/ui/trip_detail_screen_test.dart
git commit -m "Add per-trip CSV export to TripDetailScreen"
```

---

### Task 7: Full-suite verification

**Files:** none (verification only).

**Interfaces:** none — this task consumes everything from Tasks 1–6 and produces nothing new.

- [ ] **Step 1: Run the full test suite**

```bash
cd app && flutter test
```

Expected: `All tests passed!`, and the total test count is higher than the pre-plan baseline of 108 (Tasks 1–2 add 8, Task 3 adds 3, Task 5 adds 3, Task 6 adds 1 — expect roughly 123).

- [ ] **Step 2: Run `flutter analyze`**

```bash
cd app && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Manual smoke check (real device, controller-run — not a subagent self-report)**

This plan's automated tests fake `writeTempFile`/`shareFile`/`pickJsonFile`, so they never exercise the real OS share sheet, real file picker, or a real round-trip through an actual shared file. Before considering this feature done, run it once on a real device or emulator:
1. Create a trip with at least one expense.
2. Tap the backup button (top-right of the trip list) — confirm the OS share sheet opens and "Save to Files" (or equivalent) produces a readable `.json` file.
3. Tap the CSV export button on that trip's detail page — confirm the share sheet opens and the resulting `.csv` opens correctly in a spreadsheet app.
4. Uninstall and reinstall the app (or clear its data) to get back to zero trips, tap "restore from backup," pick the JSON file saved in step 2, and confirm the trip reappears with its expense intact.

Note the result in this plan's commit message or a follow-up message to the user — do not mark this feature complete without having actually run this, per this project's established "verify by executing, not by reading" discipline (see `docs/superpowers/specs/2026-07-24-travelspendplus-ui-design.md`'s development history).

- [ ] **Step 4: Commit (if Step 3 required any fixes)**

```bash
git add -A
git commit -m "Fix issues found during manual export/import verification"
```

If Step 3 required no fixes, skip this step — there's nothing to commit.
