# TravelSpendPlus UI (Plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full working UI for a single-user (or couple, non-splitting) travel expense tracker on top of the already-shipped Plan A domain/persistence layer: trip list, create/edit trip, trip detail (budget summary in three trip-lifecycle states, category pie chart, expense list), add/edit expense with inline exchange-rate capture, and trip-level exchange rate management including a currency change that reprices existing data. Chinese/English/German UI, following the OS locale. Visual style is the "海岸暖调" (coastal warm) palette confirmed with the user.

**Architecture:** Screens are plain `StatefulWidget`s taking `TripRepository` (and `Trip`/`tripId` where relevant) as required constructor parameters — no `Provider`/`InheritedWidget`/service locator, matching this project's established YAGNI stance. Screens navigate via `Navigator.push`, passing the repository down explicitly. Money/category/currency-conversion logic lives in `lib/domain/`; screens only format and display, never compute. UI text goes through Flutter's `intl`-generated `AppLocalizations` (ARB files under `lib/l10n/`), so every screen task also adds the ARB entries it needs rather than front-loading translations before any screen exists to use them.

**Tech Stack:** Flutter/Dart (existing project at `app/`), `fl_chart` for the pie chart, `intl` + `flutter_localizations` (Flutter SDK-bundled) for zh/en/de, `integration_test` (Flutter SDK-bundled) for real on-device verification. No new state-management package.

## Global Constraints

- **`AppLocalizations` import path (discovered during Task 1, applies to every later task):** the project's actual Flutter version (3.44.7) generates `app/lib/l10n/app_localizations.dart` directly rather than the older `flutter_gen`-package convention some plan text may reference — the correct import in every screen file is `import 'package:travelspendplus/l10n/app_localizations.dart';`, never `package:flutter_gen/gen_l10n/app_localizations.dart`.
- Money is always integer minor units internally (`Money.minorUnits`). UI code only ever *formats* `Money` (via `formatMoney`, Task 2) and never does currency arithmetic directly — arithmetic goes through `Money`'s own operators, `BudgetCalculator`, `CategoryBreakdownCalculator`, or the new `CurrencyConverter` (Task 3).
- Any file importing both `persistence/database.dart` and any of `Trip`/`Participant`/`Expense` must write `import '../persistence/database.dart' hide Trip, Participant, Expense;` — Drift's generated row classes collide with the domain classes of the same name (bit Plan A's Task 9). UI screens should only talk to `TripRepository`, never `AppDatabase` directly.
- Every screen takes its dependencies as required constructor parameters. Do not introduce `Provider`, `InheritedWidget`, or any DI container.
- Widget tests use `AppDatabase.memory()` + a real `TripRepository` — never a mock. This exercises real domain/persistence code.
- **No splitting UI of any kind** — no participant management, no "paid by/paid for" pickers, no balances/settlement screens. `Trip.participants` and every `Expense.paidBy`/`paidFor` are satisfied by a single silently-created default `Participant` (Task 7) that never appears in any screen. `Expense.includeInSplit` is always passed as `true` (nothing in this plan's scope ever reads it as anything else — `BalanceCalculator`, the only consumer, is out of scope).
- **`Expense.category` stores one of exactly 6 fixed lowercase keys** — `food`, `transport`, `lodging`, `shopping`, `entertainment`, `other` (Task 4) — never a display string. Every screen that shows a category localizes the key at render time via `categoryLabel()` (Task 2). No custom/user-defined categories.
- **No delete flow anywhere in this plan** — create, edit, and "mark planned as actual" only, for both trips and expenses.
- **No dark mode in this plan** — light theme only (Task 6).
- Package versions: add packages via `flutter pub add <name>` and let the resolver pick versions compatible with the pinned Flutter SDK, rather than hardcoding numbers — Plan A hit a resolver conflict this way and fixed it by accepting the resolver's suggested version; do the same here if `flutter pub get` reports a conflict.
- **Real on-device persistence (`AppDatabase.openOnDevice()`) has never been exercised by any test through Plan A** — every Plan A test used `AppDatabase.memory()`. Task 13's integration test is the first real exercise of that code path, and is only complete once the controller has personally run it against a real Android target and seen it pass — a subagent's "tests pass" self-report is not sufficient for that task specifically.
- **Do not attempt macOS desktop as a verification target** — this environment has Xcode Command Line Tools only, not full Xcode; `flutter build macos --debug` fails with `xcrun: error: unable to find utility "xcodebuild"` (checked directly).
- **Do not target Chrome/web for any verification** — `sqlite3_flutter_libs`/`NativeDatabase` (used by `AppDatabase`) are incompatible with Flutter web.
- The real verification target for Task 13 is an Android emulator: AVD `travelspend_test` (API 35, `google_apis_playstore`, `arm64-v8a`, matching the Mac's Apple Silicon), already created for Plan A's own consideration — create it if it doesn't already exist (`flutter emulators` to check, `flutter emulators --create --name travelspend_test` plus AVD Manager config for API 35/arm64-v8a if missing). Run `flutter test integration_test/<file> -d <device-id>` (find `<device-id>` via `flutter devices` once booted).
- Add the exact `Key('...')` identifiers specified in each task's widget code — Task 13's integration test targets these keys directly.

---

### Task 1: Add UI dependencies and stand up the i18n pipeline

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/l10n.yaml`
- Create: `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_zh.arb`, `app/lib/l10n/app_de.arb`
- Modify: `app/lib/main.dart`
- Test: `app/test/widget_test.dart` (existing file — replace its contents; the current file tests the leftover default counter template, which Task 12 removes)

**Interfaces:**
- Produces: `AppLocalizations` (generated by `flutter gen-l10n` directly into `app/lib/l10n/app_localizations.dart` on this project's actual Flutter version — 3.44.7, confirmed during Task 1 — imported as `package:travelspendplus/l10n/app_localizations.dart`, **not** `package:flutter_gen/gen_l10n/...` as older Flutter/`flutter_gen`-based setups use), with `AppLocalizations.appTitle` available. `MaterialApp` in `main.dart` wired with `localizationsDelegates`/`supportedLocales`. Every later screen task adds its own ARB keys to these same three files and re-runs `flutter gen-l10n`.

- [ ] **Step 1: Add packages**

```bash
cd app && flutter pub add fl_chart intl
flutter pub add --dev integration_test --sdk=flutter
```

Expected: both exit 0; `fl_chart` and `intl` appear under `dependencies:`, `integration_test` under `dev_dependencies:` in `pubspec.yaml`. If `flutter pub get` reports a conflict (common for `intl`, which `flutter_localizations` pins tightly), run `flutter pub outdated` and accept the resolver's suggested compatible version.

- [ ] **Step 2: Add flutter_localizations and enable generate**

Add to `app/pubspec.yaml` under `dependencies:`:
```yaml
  flutter_localizations:
    sdk: flutter
```

Add under the top-level `flutter:` section (alongside `uses-material-design: true`):
```yaml
  generate: true
```

- [ ] **Step 3: Create l10n.yaml**

```yaml
# app/l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

- [ ] **Step 4: Create the three ARB files with just the app title for now**

```json
// app/lib/l10n/app_en.arb
{
  "@@locale": "en",
  "appTitle": "TravelSpendPlus",
  "@appTitle": {"description": "The application title"}
}
```

```json
// app/lib/l10n/app_zh.arb
{
  "@@locale": "zh",
  "appTitle": "TravelSpendPlus"
}
```

```json
// app/lib/l10n/app_de.arb
{
  "@@locale": "de",
  "appTitle": "TravelSpendPlus"
}
```

- [ ] **Step 5: Generate and verify**

```bash
flutter gen-l10n
flutter pub get
flutter analyze
```

Expected: `flutter gen-l10n` creates `app/lib/l10n/app_localizations.dart` (and `_en`/`_zh`/`_de` variants) with no errors; `flutter analyze` reports "No issues found!" (nothing references the generated code yet).

- [ ] **Step 6: Wire MaterialApp with localization support and update the smoke test**

Replace `app/lib/main.dart` entirely:

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

void main() {
  runApp(const TravelSpendPlusApp());
}

class TravelSpendPlusApp extends StatelessWidget {
  const TravelSpendPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('TravelSpendPlus'))),
    );
  }
}
```

(The real `home:` screen and theme land in Tasks 6/12 — this is a minimal placeholder so the app builds and the localization pipeline is provably wired end to end.)

Replace `app/test/widget_test.dart` entirely (the previous version tested the default counter template, which no longer exists):

```dart
// app/test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/main.dart';

void main() {
  testWidgets('app builds and resolves a localized title', (tester) async {
    await tester.pumpWidget(const TravelSpendPlusApp());
    await tester.pumpAndSettle();
    expect(find.text('TravelSpendPlus'), findsWidgets);
  });
}
```

- [ ] **Step 7: Run test and verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib/l10n lib/main.dart test/widget_test.dart
git commit -m "Stand up i18n pipeline (zh/en/de) and UI dependencies"
```

---

### Task 2: Formatting helpers (money, date, category labels)

**Files:**
- Create: `app/lib/ui/formatting.dart`
- Test: `app/test/ui/formatting_test.dart`

**Interfaces:**
- Consumes: `Money` (existing), `AppLocalizations` (Task 1).
- Produces: `formatMoney(Money) -> String`, `formatDate(BuildContext, DateTime) -> String`, `categoryLabel(BuildContext, String key) -> String` — used by every screen task from here on.

- [ ] **Step 1: Add the category labels to all three ARB files**

Append to `app/lib/l10n/app_en.arb` (before the closing `}`, comma-separated with the existing `appTitle` entry):
```json
  "categoryFood": "Food",
  "categoryTransport": "Transport",
  "categoryLodging": "Lodging",
  "categoryShopping": "Shopping",
  "categoryEntertainment": "Entertainment",
  "categoryOther": "Other"
```

Append to `app/lib/l10n/app_zh.arb`:
```json
  "categoryFood": "餐饮",
  "categoryTransport": "交通",
  "categoryLodging": "住宿",
  "categoryShopping": "购物",
  "categoryEntertainment": "娱乐",
  "categoryOther": "其他"
```

Append to `app/lib/l10n/app_de.arb`:
```json
  "categoryFood": "Essen",
  "categoryTransport": "Transport",
  "categoryLodging": "Unterkunft",
  "categoryShopping": "Einkaufen",
  "categoryEntertainment": "Unterhaltung",
  "categoryOther": "Sonstiges"
```

Run `flutter gen-l10n` to regenerate before writing code that references these getters.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/ui/formatting_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/ui/formatting.dart';

void main() {
  test('formatMoney includes the currency code and two decimal places', () {
    final result = formatMoney(Money.fromMajor(1234.5, 'EUR'));
    expect(result, contains('EUR'));
    expect(result, contains('1,234.50'));
  });

  test('formatMoney handles a zero amount', () {
    final result = formatMoney(Money(minorUnits: 0, currencyCode: 'USD'));
    expect(result, contains('0.00'));
  });

  testWidgets('categoryLabel resolves the current locale', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(categoryLabel(capturedContext, 'food'), '餐饮');
    expect(categoryLabel(capturedContext, 'transport'), '交通');
  });

  testWidgets('formatDate uses a short readable form', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(formatDate(capturedContext, DateTime(2026, 7, 24)), 'Jul 24, 2026');
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/formatting_test.dart`
Expected: FAIL — `package:travelspendplus/ui/formatting.dart` doesn't exist.

- [ ] **Step 4: Implement formatting.dart**

```dart
// app/lib/ui/formatting.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/money.dart';

String formatMoney(Money money) {
  final format = NumberFormat.currency(symbol: '${money.currencyCode} ', decimalDigits: 2);
  return format.format(money.major);
}

String formatDate(BuildContext context, DateTime date) {
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
}

String categoryLabel(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context)!;
  switch (key) {
    case 'food':
      return l10n.categoryFood;
    case 'transport':
      return l10n.categoryTransport;
    case 'lodging':
      return l10n.categoryLodging;
    case 'shopping':
      return l10n.categoryShopping;
    case 'entertainment':
      return l10n.categoryEntertainment;
    case 'other':
      return l10n.categoryOther;
    default:
      throw ArgumentError('Unknown category key: $key');
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/formatting_test.dart`
Expected: PASS, all 4 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n lib/ui/formatting.dart test/ui/formatting_test.dart
git commit -m "Add money/date/category formatting helpers"
```

---

### Task 3: Domain additions — category key list and bidirectional currency conversion

**Files:**
- Create: `app/lib/domain/expense_category.dart`
- Create: `app/lib/domain/currency_converter.dart`
- Test: `app/test/domain/expense_category_test.dart`
- Test: `app/test/domain/currency_converter_test.dart`

**Interfaces:**
- Consumes: `Money`, `ExchangeRate` (existing).
- Produces: `kExpenseCategoryKeys -> List<String>` (used by Task 10's category picker), `CurrencyConverter.convert({required Money amount, required String toCurrency, required List<ExchangeRate> rates, required String homeCurrency}) -> Money` (used by Task 11's currency-view switcher).

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/domain/expense_category_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/expense_category.dart';

void main() {
  test('exactly the six fixed category keys, in a stable order', () {
    expect(kExpenseCategoryKeys,
        ['food', 'transport', 'lodging', 'shopping', 'entertainment', 'other']);
  });
}
```

```dart
// app/test/domain/currency_converter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/currency_converter.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';
import 'package:travelspendplus/domain/money.dart';

void main() {
  final rates = [
    const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'CNY', rate: 0.05),
    const ExchangeRate(fromCurrency: 'USD', toCurrency: 'CNY', rate: 7.2),
  ];

  test('same currency is returned unchanged', () {
    final amount = Money.fromMajor(100, 'CNY');
    final result = CurrencyConverter.convert(
        amount: amount, toCurrency: 'CNY', rates: rates, homeCurrency: 'CNY');
    expect(result, amount);
  });

  test('foreign to home uses the matching rate directly', () {
    final result = CurrencyConverter.convert(
      amount: Money.fromMajor(1000, 'JPY'),
      toCurrency: 'CNY',
      rates: rates,
      homeCurrency: 'CNY',
    );
    expect(result, Money.fromMajor(50, 'CNY'));
  });

  test('home to foreign inverts the matching rate', () {
    final result = CurrencyConverter.convert(
      amount: Money.fromMajor(50, 'CNY'),
      toCurrency: 'JPY',
      rates: rates,
      homeCurrency: 'CNY',
    );
    expect(result.currencyCode, 'JPY');
    expect(result.major, closeTo(1000, 0.01));
  });

  test('foreign to foreign chains through home currency', () {
    final result = CurrencyConverter.convert(
      amount: Money.fromMajor(1000, 'JPY'), // = 50 CNY
      toCurrency: 'USD',
      rates: rates,
      homeCurrency: 'CNY',
    );
    expect(result.currencyCode, 'USD');
    expect(result.major, closeTo(50 / 7.2, 0.01));
  });

  test('throws a clear error when no rate exists for the requested currency', () {
    expect(
      () => CurrencyConverter.convert(
        amount: Money.fromMajor(10, 'GBP'),
        toCurrency: 'CNY',
        rates: rates,
        homeCurrency: 'CNY',
      ),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/domain/expense_category_test.dart test/domain/currency_converter_test.dart`
Expected: FAIL — neither `lib/domain/expense_category.dart` nor `lib/domain/currency_converter.dart` exists.

- [ ] **Step 3: Implement expense_category.dart**

```dart
// app/lib/domain/expense_category.dart
/// The fixed set of expense categories (TravelSpend's own default set).
/// `Expense.category` always stores one of these lowercase keys, never a
/// display string — screens localize the key via `categoryLabel()`
/// (`lib/ui/formatting.dart`) so category statistics don't fragment across
/// languages. No custom/user-defined categories in this app.
const List<String> kExpenseCategoryKeys = [
  'food',
  'transport',
  'lodging',
  'shopping',
  'entertainment',
  'other',
];
```

- [ ] **Step 4: Implement currency_converter.dart**

```dart
// app/lib/domain/currency_converter.dart
import 'exchange_rate.dart';
import 'money.dart';

/// Converts [amount] into [toCurrency] using a trip's manually maintained
/// [rates] list, each expressed as "1 fromCurrency = rate homeCurrency"
/// (every rate's `toCurrency` is the trip's [homeCurrency] — see
/// `ExchangeRate`). Unlike `ExchangeRate.convert`, which only converts in
/// the single direction it was defined, this supports any-to-any
/// conversion by routing through [homeCurrency]: foreign->home uses the
/// matching rate directly, home->foreign inverts it, foreign->foreign
/// chains both steps.
class CurrencyConverter {
  static Money convert({
    required Money amount,
    required String toCurrency,
    required List<ExchangeRate> rates,
    required String homeCurrency,
  }) {
    if (amount.currencyCode == toCurrency) return amount;

    final Money inHome;
    if (amount.currencyCode == homeCurrency) {
      inHome = amount;
    } else {
      final forward = rates.firstWhere(
        (r) => r.fromCurrency == amount.currencyCode && r.toCurrency == homeCurrency,
        orElse: () => throw ArgumentError(
          'No exchange rate from ${amount.currencyCode} to $homeCurrency',
        ),
      );
      inHome = forward.convert(amount);
    }

    if (toCurrency == homeCurrency) return inHome;

    final inverse = rates.firstWhere(
      (r) => r.fromCurrency == toCurrency && r.toCurrency == homeCurrency,
      orElse: () =>
          throw ArgumentError('No exchange rate from $toCurrency to $homeCurrency'),
    );
    return ExchangeRate(
      fromCurrency: homeCurrency,
      toCurrency: toCurrency,
      rate: 1 / inverse.rate,
    ).convert(inHome);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/domain/expense_category_test.dart test/domain/currency_converter_test.dart`
Expected: PASS, all 6 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/expense_category.dart lib/domain/currency_converter.dart test/domain/expense_category_test.dart test/domain/currency_converter_test.dart
git commit -m "Add fixed expense category keys and bidirectional CurrencyConverter"
```

---

### Task 4: Persistence — trip-level exchange rate table (schema v2)

**Files:**
- Modify: `app/lib/persistence/database.dart`
- Test: `app/test/persistence/database_test.dart` (existing file — add to it)

**Interfaces:**
- Consumes: existing `Trips`, `Participants`, `Expenses` tables.
- Produces: `TripExchangeRates` Drift table (`tripId`, `fromCurrency`, `rate`), `schemaVersion` bumped to 2 with a migration — used by Task 5's repository methods.

- [ ] **Step 1: Write the failing test**

Add to `app/test/persistence/database_test.dart` (inside the existing `main()`):

```dart
  test('schema v2 has a queryable tripExchangeRates table', () async {
    final db = AppDatabase.memory();
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 10, 5),
          endDate: DateTime(2026, 10, 12),
          homeCurrency: 'CNY',
          totalBudgetMinorUnits: 2000000,
        ));
    await db.into(db.tripExchangeRates).insert(TripExchangeRatesCompanion.insert(
          tripId: 't1',
          fromCurrency: 'JPY',
          rate: 0.05,
        ));
    final rows = await (db.select(db.tripExchangeRates)
          ..where((r) => r.tripId.equals('t1')))
        .get();
    expect(rows.length, 1);
    expect(rows.first.fromCurrency, 'JPY');
    expect(rows.first.rate, 0.05);
    await db.close();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/persistence/database_test.dart`
Expected: FAIL — `tripExchangeRates`/`TripExchangeRatesCompanion` don't exist (compile error).

- [ ] **Step 3: Add the table and migration**

In `app/lib/persistence/database.dart`, add a new table class (after the existing `Expenses` class):

```dart
/// A trip's manually maintained "1 fromCurrency = rate homeCurrency" list
/// (see `CurrencyConverter`). `toCurrency` isn't stored — it's always the
/// owning trip's current `homeCurrency`, looked up via `tripId` when read.
class TripExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get fromCurrency => text()();
  RealColumn get rate => real()();
}
```

Update the `@DriftDatabase` annotation and bump the schema version:

```dart
@DriftDatabase(tables: [Trips, Participants, Expenses, TripExchangeRates])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.memory() : super(NativeDatabase.memory());

  static Future<AppDatabase> openOnDevice() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'travelspendplus.sqlite');
    return AppDatabase(NativeDatabase.createInBackground(File(filePath)));
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(tripExchangeRates);
          }
        },
      );
}
```

- [ ] **Step 4: Regenerate Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `lib/persistence/database.g.dart` regenerates with `TripExchangeRates`/`TripExchangeRatesCompanion`/`$TripExchangeRatesTable` added, no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/persistence/database_test.dart`
Expected: PASS, including the new test.

- [ ] **Step 6: Commit**

```bash
git add lib/persistence/database.dart lib/persistence/database.g.dart test/persistence/database_test.dart
git commit -m "Add TripExchangeRates table, bump schema to v2"
```

---

### Task 5: TripRepository additions — getAllTrips, updateTrip, exchange rates, changeHomeCurrency

**Files:**
- Modify: `app/lib/persistence/trip_repository.dart`
- Test: `app/test/persistence/trip_repository_test.dart` (existing file — add to it)

**Interfaces:**
- Consumes: `AppDatabase`, `TripExchangeRates` (Task 4), `Trip`, `Participant`, `Expense`, `ExchangeRate`, `CurrencyConverter` (not needed here — the reprice math is done directly, see Step 5).
- Produces: `TripRepository.getAllTrips() -> Future<List<Trip>>` (used by Task 8), `TripRepository.updateTrip(Trip) -> Future<void>` (used by Task 7's edit mode and Task 9's home-currency change), `TripRepository.getExchangeRates(String tripId) -> Future<List<ExchangeRate>>` and `TripRepository.setExchangeRate(String tripId, ExchangeRate rate) -> Future<void>` (used by Task 9 and Task 10's inline rate capture), `TripRepository.changeHomeCurrency({required String tripId, required String newCurrency, required double oldToNewRate}) -> Future<void>` (used by Task 9).

- [ ] **Step 1: Write the failing tests**

Add to `app/test/persistence/trip_repository_test.dart` (reuse the existing `alice`, `makeTrip()` helpers already in that file — `makeTrip()` builds a `Trip` with `homeCurrency: 'EUR'`, `id: 't1'`, one participant):

```dart
  test('getAllTrips returns an empty list when there are no trips', () async {
    expect(await repo.getAllTrips(), isEmpty);
  });

  test('getAllTrips returns every trip with its participants', () async {
    await repo.createTrip(makeTrip()); // uses participant 'p1' (alice)
    final secondTrip = Trip(
      id: 't2',
      name: 'Italy',
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 3, 5),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(500, 'EUR'),
      // Participants.id is a global primary key, not scoped per trip — must
      // be a fresh id, not alice's 'p1' again, or this insert throws a
      // UNIQUE-constraint error (caught during Task 5's own implementation).
      participants: [const Participant(id: 'p3', name: 'Carol')],
    );
    await repo.createTrip(secondTrip);

    final trips = await repo.getAllTrips();
    expect(trips.length, 2);
    expect(trips.map((t) => t.name).toSet(), {'Japan', 'Italy'});
  });

  test('updateTrip changes name, dates, and budget but not participants', () async {
    final trip = makeTrip();
    await repo.createTrip(trip);
    final updated = Trip(
      id: trip.id,
      name: 'Japan (renamed)',
      startDate: DateTime(2026, 10, 6),
      endDate: DateTime(2026, 10, 13),
      homeCurrency: trip.homeCurrency,
      totalBudget: Money.fromMajor(3000, trip.homeCurrency),
      participants: trip.participants,
    );
    await repo.updateTrip(updated);

    final reloaded = await repo.getTrip(trip.id);
    expect(reloaded!.name, 'Japan (renamed)');
    expect(reloaded.startDate, DateTime(2026, 10, 6));
    expect(reloaded.totalBudget, Money.fromMajor(3000, trip.homeCurrency));
  });

  test('setExchangeRate then getExchangeRates round-trips, and re-setting the same currency replaces it',
      () async {
    await repo.createTrip(makeTrip());
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0062));
    var rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.rate, 0.0062);

    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0065));
    rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1, reason: 'setting the same currency again should replace, not duplicate');
    expect(rates.first.rate, 0.0065);
  });

  test('changeHomeCurrency rescales the budget, every expense, and an unrelated rate', () async {
    await repo.createTrip(makeTrip()); // EUR home currency, 1000 EUR budget
    // USD is unrelated to the currency change below (EUR -> JPY) — its rate
    // must be rescaled (still meaningful: "1 USD = ? JPY" after the change),
    // not deleted. The self-referential case (a rate entry for the currency
    // you're changing *to*) is covered by the next test.
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'USD', toCurrency: 'EUR', rate: 0.92));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 10, 6),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));

    // 1 EUR = 155 JPY
    await repo.changeHomeCurrency(tripId: 't1', newCurrency: 'JPY', oldToNewRate: 155);

    final trip = await repo.getTrip('t1');
    expect(trip!.homeCurrency, 'JPY');
    expect(trip.totalBudget.major, closeTo(1000 * 155, 0.01));

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amountInHomeCurrency.currencyCode, 'JPY');
    expect(expenses.first.amountInHomeCurrency.major, closeTo(30 * 155, 0.01));

    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.fromCurrency, 'USD');
    expect(rates.first.toCurrency, 'JPY');
    expect(rates.first.rate, closeTo(0.92 * 155, 0.0001));
  });

  test('changeHomeCurrency deletes (not rescales) a rate entry for the currency being switched to',
      () async {
    await repo.createTrip(makeTrip()); // EUR home currency
    // A pre-existing "1 JPY = 0.0062 EUR" rate becomes meaningless the
    // moment JPY itself becomes the home currency — rescaling it would
    // produce a self-referential "1 JPY = X JPY" row that can never be
    // cleaned up later (this app has no delete-a-single-rate flow).
    await repo.setExchangeRate(
        't1', const ExchangeRate(fromCurrency: 'JPY', toCurrency: 'EUR', rate: 0.0062));

    await repo.changeHomeCurrency(tripId: 't1', newCurrency: 'JPY', oldToNewRate: 155);

    final rates = await repo.getExchangeRates('t1');
    expect(rates, isEmpty);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/persistence/trip_repository_test.dart`
Expected: FAIL — `getAllTrips`, `updateTrip`, `getExchangeRates`, `setExchangeRate`, `changeHomeCurrency` aren't defined.

- [ ] **Step 3: Implement getAllTrips and updateTrip**

Add to `app/lib/persistence/trip_repository.dart`, inside the `TripRepository` class (right after `getTrip`):

```dart
  Future<List<Trip>> getAllTrips() async {
    final tripRows = await _db.select(_db.trips).get();
    final trips = <Trip>[];
    for (final tripRow in tripRows) {
      final participantRows = await (_db.select(_db.participants)
            ..where((p) => p.tripId.equals(tripRow.id)))
          .get();
      trips.add(Trip(
        id: tripRow.id,
        name: tripRow.name,
        startDate: tripRow.startDate,
        endDate: tripRow.endDate,
        homeCurrency: tripRow.homeCurrency,
        totalBudget: Money(
          minorUnits: tripRow.totalBudgetMinorUnits,
          currencyCode: tripRow.homeCurrency,
        ),
        participants:
            participantRows.map((row) => Participant(id: row.id, name: row.name)).toList(),
      ));
    }
    return trips;
  }

  Future<void> updateTrip(Trip trip) async {
    await (_db.update(_db.trips)..where((t) => t.id.equals(trip.id))).write(
      TripsCompanion(
        name: Value(trip.name),
        startDate: Value(trip.startDate),
        endDate: Value(trip.endDate),
        homeCurrency: Value(trip.homeCurrency),
        totalBudgetMinorUnits: Value(trip.totalBudget.minorUnits),
      ),
    );
  }
```

- [ ] **Step 4: Implement exchange rate read/write**

Add to the same class:

```dart
  Future<List<ExchangeRate>> getExchangeRates(String tripId) async {
    final tripRow =
        await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (tripRow == null) return [];
    final rows = await (_db.select(_db.tripExchangeRates)
          ..where((r) => r.tripId.equals(tripId)))
        .get();
    return rows
        .map((row) => ExchangeRate(
              fromCurrency: row.fromCurrency,
              toCurrency: tripRow.homeCurrency,
              rate: row.rate,
            ))
        .toList();
  }

  Future<void> setExchangeRate(String tripId, ExchangeRate rate) async {
    final existing = await (_db.select(_db.tripExchangeRates)
          ..where((r) => r.tripId.equals(tripId) & r.fromCurrency.equals(rate.fromCurrency)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.tripExchangeRates)..where((r) => r.id.equals(existing.id)))
          .write(TripExchangeRatesCompanion(rate: Value(rate.rate)));
    } else {
      await _db.into(_db.tripExchangeRates).insert(TripExchangeRatesCompanion.insert(
            tripId: tripId,
            fromCurrency: rate.fromCurrency,
            rate: rate.rate,
          ));
    }
  }
```

- [ ] **Step 5: Implement changeHomeCurrency as an atomic reprice**

Add to the same class (uses Drift's `transaction()` so the budget/expenses/rates update together or not at all):

```dart
  /// Changes a trip's home currency and rescales everything already
  /// denominated in the old one by [oldToNewRate] ("1 old home currency =
  /// oldToNewRate new home currency") — `Expense.amountInHomeCurrency` and
  /// `Trip.totalBudget` are both stored as plain numbers re-labeled with
  /// whatever the trip's *current* home currency is, so simply changing
  /// the label without rescaling the numbers would silently corrupt every
  /// existing total. See docs/superpowers/specs/2026-07-24-travelspendplus-ui-design.md
  /// section 五 for why this replaced an earlier "just clear the rate
  /// table" design.
  Future<void> changeHomeCurrency({
    required String tripId,
    required String newCurrency,
    required double oldToNewRate,
  }) async {
    await _db.transaction(() async {
      final tripRow =
          await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingle();
      final newBudgetMinorUnits =
          (tripRow.totalBudgetMinorUnits * oldToNewRate).round();
      await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          homeCurrency: Value(newCurrency),
          totalBudgetMinorUnits: Value(newBudgetMinorUnits),
        ),
      );

      final expenseRows =
          await (_db.select(_db.expenses)..where((e) => e.tripId.equals(tripId))).get();
      for (final row in expenseRows) {
        final newAmountInHome =
            (row.amountInHomeCurrencyMinorUnits * oldToNewRate).round();
        await (_db.update(_db.expenses)..where((e) => e.id.equals(row.id))).write(
          ExpensesCompanion(amountInHomeCurrencyMinorUnits: Value(newAmountInHome)),
        );
      }

      final rateRows = await (_db.select(_db.tripExchangeRates)
            ..where((r) => r.tripId.equals(tripId)))
          .get();
      for (final row in rateRows) {
        if (row.fromCurrency == newCurrency) {
          // This currency IS the new home currency now — a rescaled "1 X =
          // Y X" row would be self-referential nonsense, and this app has
          // no delete-a-single-rate flow to ever clean it up later, so it
          // must be deleted here rather than rescaled.
          await (_db.delete(_db.tripExchangeRates)..where((r) => r.id.equals(row.id))).go();
        } else {
          await (_db.update(_db.tripExchangeRates)..where((r) => r.id.equals(row.id)))
              .write(TripExchangeRatesCompanion(rate: Value(row.rate * oldToNewRate)));
        }
      }
    });
  }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/persistence/trip_repository_test.dart`
Expected: PASS, all tests including the 5 new ones.

- [ ] **Step 7: Commit**

```bash
git add lib/persistence/trip_repository.dart test/persistence/trip_repository_test.dart
git commit -m "Add getAllTrips, updateTrip, exchange rate CRUD, and changeHomeCurrency"
```

---

### Task 6: App theme — "海岸暖调" (coastal warm) palette

**Files:**
- Create: `app/lib/ui/theme.dart`
- Test: `app/test/ui/theme_test.dart`

**Interfaces:**
- Produces: `AppColors` (static semantic colors not covered by `ColorScheme`: `planned`, `actual`, and 6 category chart colors), `buildAppTheme() -> ThemeData` — used by Task 12 (main.dart) and by Tasks 7-11 wherever a status chip or chart color is needed.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/ui/theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:travelspendplus/ui/theme.dart';

void main() {
  test('buildAppTheme uses the coastal-warm primary color', () {
    final theme = buildAppTheme();
    expect(theme.colorScheme.primary, const Color(0xFFE0693F));
    expect(theme.colorScheme.secondary, const Color(0xFF2A9D8F));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFBF6EF));
  });

  test('AppColors exposes exactly 6 category chart colors', () {
    expect(AppColors.categoryChartColors.length, 6);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/theme_test.dart`
Expected: FAIL — `package:travelspendplus/ui/theme.dart` doesn't exist.

- [ ] **Step 3: Implement theme.dart**

```dart
// app/lib/ui/theme.dart
import 'package:flutter/material.dart';

/// The "海岸暖调" (coastal warm) palette, confirmed with the user against a
/// real-data mockup on 2026-07-24 — see
/// docs/superpowers/specs/2026-07-24-travelspendplus-ui-design.md section 四.
/// Light mode only in this plan (dark mode explicitly deferred).
class AppColors {
  static const coral = Color(0xFFE0693F); // primary / CTA
  static const teal = Color(0xFF2A9D8F); // secondary / "actual" status
  static const gold = Color(0xFFDDA63A); // "planned" status
  static const cream = Color(0xFFFBF6EF); // page background
  static const charcoal = Color(0xFF2B241D); // primary text
  static const mutedText = Color(0xFF8A7F70); // secondary text
  static const border = Color(0xFFEFE4D5);

  /// Fixed order, matches `kExpenseCategoryKeys` — food, transport,
  /// lodging, shopping, entertainment, other.
  static const categoryChartColors = [
    coral,
    teal,
    gold,
    Color(0xFF6D8B96), // dusty blue
    Color(0xFF8AA17E), // sage
    Color(0xFFB08968), // warm taupe
  ];
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.coral,
    brightness: Brightness.light,
    primary: AppColors.coral,
    secondary: AppColors.teal,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.cream,
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.charcoal,
          displayColor: AppColors.charcoal,
        ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/theme_test.dart`
Expected: PASS, both tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/theme.dart test/ui/theme_test.dart
git commit -m "Add coastal-warm app theme"
```

---

### Task 7: CreateTripScreen (create and edit)

**Files:**
- Create: `app/lib/ui/create_trip_screen.dart`
- Test: `app/test/ui/create_trip_screen_test.dart`

**Interfaces:**
- Consumes: `Trip`, `Participant`, `Money`, `TripRepository.createTrip`, `TripRepository.updateTrip` (Task 5), `formatDate` (Task 2).
- Produces: `CreateTripScreen({required TripRepository repository, Trip? existingTrip})` — `existingTrip: null` means create mode (silently generates one default `Participant` and a new trip id); non-null means edit mode (reuses the existing trip's id and participants, only mutates name/dates/budget, and calls `updateTrip`). On success calls `Navigator.pop(context, true)`. Used by Task 8 (create) and Task 11 (edit, via a settings menu). Test-only `Key`s: `tripNameField`, `tripBudgetField`, `saveTripButton`.

- [ ] **Step 1: Add this screen's ARB strings**

Append to `app/lib/l10n/app_en.arb`:
```json
  "newTrip": "New Trip",
  "editTrip": "Edit Trip",
  "tripName": "Trip name",
  "startDate": "Start date",
  "endDate": "End date",
  "totalBudget": "Total budget",
  "homeCurrency": "Home currency",
  "createTrip": "Create Trip",
  "saveChanges": "Save Changes",
  "errorEnterTripName": "Enter a trip name",
  "errorPositiveAmount": "Enter a positive amount",
  "errorEndDateBeforeStart": "End date must be on or after the start date",
  "errorCurrencyCode": "Enter a 3-letter currency code"
```

Append to `app/lib/l10n/app_zh.arb`:
```json
  "newTrip": "新建行程",
  "editTrip": "编辑行程",
  "tripName": "行程名称",
  "startDate": "开始日期",
  "endDate": "结束日期",
  "totalBudget": "总预算",
  "homeCurrency": "本位币",
  "createTrip": "创建行程",
  "saveChanges": "保存修改",
  "errorEnterTripName": "请输入行程名称",
  "errorPositiveAmount": "请输入大于0的金额",
  "errorEndDateBeforeStart": "结束日期不能早于开始日期",
  "errorCurrencyCode": "请输入3位货币代码"
```

Append to `app/lib/l10n/app_de.arb`:
```json
  "newTrip": "Neue Reise",
  "editTrip": "Reise bearbeiten",
  "tripName": "Reisename",
  "startDate": "Startdatum",
  "endDate": "Enddatum",
  "totalBudget": "Gesamtbudget",
  "homeCurrency": "Heimatwährung",
  "createTrip": "Reise erstellen",
  "saveChanges": "Änderungen speichern",
  "errorEnterTripName": "Reisenamen eingeben",
  "errorPositiveAmount": "Positiven Betrag eingeben",
  "errorEndDateBeforeStart": "Enddatum darf nicht vor dem Startdatum liegen",
  "errorCurrencyCode": "3-stelligen Währungscode eingeben"
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/ui/create_trip_screen_test.dart
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
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '1000');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final trips = await repo.getAllTrips();
    expect(trips.length, 1);
    expect(trips.first.name, 'Japan Trip');
    expect(trips.first.participants.length, 1);
  });

  testWidgets('empty name shows a validation error and does not save', (tester) async {
    await tester.pumpWidget(wrap(CreateTripScreen(repository: repo)));
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

    await tester.enterText(find.byKey(const Key('tripNameField')), 'Japan Trip (updated)');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.name, 'Japan Trip (updated)');
    expect(reloaded.participants.map((p) => p.id).toList(), ['p1']);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/create_trip_screen_test.dart`
Expected: FAIL — `package:travelspendplus/ui/create_trip_screen.dart` doesn't exist.

- [ ] **Step 4: Implement CreateTripScreen**

```dart
// app/lib/ui/create_trip_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/money.dart';
import '../domain/participant.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'formatting.dart';

class CreateTripScreen extends StatefulWidget {
  final TripRepository repository;
  final Trip? existingTrip;
  const CreateTripScreen({super.key, required this.repository, this.existingTrip});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;
  late final TextEditingController _budgetController;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _dateError;

  bool get _isEditing => widget.existingTrip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.existingTrip;
    _nameController = TextEditingController(text: trip?.name ?? '');
    _currencyController = TextEditingController(text: trip?.homeCurrency ?? 'CNY');
    _budgetController =
        TextEditingController(text: trip != null ? trip.totalBudget.major.toString() : '');
    _startDate = trip?.startDate ?? DateTime.now();
    _endDate = trip?.endDate ?? DateTime.now().add(const Duration(days: 6));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _dateError = _endDate.isBefore(_startDate) ? l10n.errorEndDateBeforeStart : null;
    });
    if (!_formKey.currentState!.validate() || _dateError != null) return;

    final currency = _currencyController.text.trim().toUpperCase();
    final budget = Money.fromMajor(double.parse(_budgetController.text), currency);

    if (_isEditing) {
      final existing = widget.existingTrip!;
      await widget.repository.updateTrip(Trip(
        id: existing.id,
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        homeCurrency: existing.homeCurrency, // currency changes go through ExchangeRateSettingsScreen only
        totalBudget: Money(minorUnits: budget.minorUnits, currencyCode: existing.homeCurrency),
        participants: existing.participants,
      ));
    } else {
      final defaultParticipant = Participant(id: const Uuid().v4(), name: 'Me');
      await widget.repository.createTrip(Trip(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        homeCurrency: currency,
        totalBudget: budget,
        participants: [defaultParticipant],
      ));
    }
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.editTrip : l10n.newTrip)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('tripNameField'),
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.tripName),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l10n.errorEnterTripName : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.startDate),
              subtitle: Text(formatDate(context, _startDate)),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              title: Text(l10n.endDate),
              subtitle: Text(formatDate(context, _endDate)),
              onTap: () => _pickDate(isStart: false),
            ),
            if (_dateError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_dateError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            if (!_isEditing)
              TextFormField(
                controller: _currencyController,
                decoration: InputDecoration(labelText: l10n.homeCurrency),
                textCapitalization: TextCapitalization.characters,
                validator: (value) =>
                    (value?.trim().length ?? 0) == 3 ? null : l10n.errorCurrencyCode,
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('tripBudgetField'),
              controller: _budgetController,
              decoration: InputDecoration(labelText: l10n.totalBudget),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return (parsed != null && parsed > 0) ? null : l10n.errorPositiveAmount;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('saveTripButton'),
              onPressed: _save,
              child: Text(_isEditing ? l10n.saveChanges : l10n.createTrip),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: editing a trip does not let the user change `homeCurrency` inline (the field is hidden in edit mode) — that mutation only happens through Task 9's `ExchangeRateSettingsScreen`, which does the reprice via `changeHomeCurrency` rather than a plain field edit.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/create_trip_screen_test.dart`
Expected: PASS, all 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/create_trip_screen.dart test/ui/create_trip_screen_test.dart lib/l10n
git commit -m "Add CreateTripScreen (create and edit modes)"
```

---

### Task 8: AddExpenseScreen

**Files:**
- Create: `app/lib/ui/add_expense_screen.dart`
- Test: `app/test/ui/add_expense_screen_test.dart`

**Interfaces:**
- Consumes: `Trip`, `Participant`, `Expense`, `ExpenseStatus`, `Money`, `ExchangeRate`, `kExpenseCategoryKeys` (Task 3), `TripRepository.addExpense`, `TripRepository.getExchangeRates`, `TripRepository.setExchangeRate` (Task 5), `formatDate`, `categoryLabel` (Task 2).
- Produces: `AddExpenseScreen({required Trip trip, required TripRepository repository})` — a full-screen form, create-only (no edit mode; "mark planned as actual" is a separate lightweight dialog built directly into Task 10's `TripDetailScreen`, not this screen). On successful save calls `Navigator.pop(context, true)`. Used by Task 10. Test-only `Key`s: `expenseCategoryField` (a `DropdownButtonFormField`), `expenseAmountField`, `expenseCurrencyField`, `expenseExchangeRateField` (only present when the chosen currency isn't the home currency and has no existing rate), `expenseDescriptionField`, `saveExpenseButton`.

- [ ] **Step 1: Add this screen's ARB strings**

Append to `app/lib/l10n/app_en.arb`:
```json
  "addExpense": "Add Expense",
  "category": "Category",
  "amount": "Amount",
  "currency": "Currency",
  "description": "Description",
  "date": "Date",
  "statusPlanned": "Planned",
  "statusActual": "Actual",
  "saveExpense": "Save Expense",
  "errorSelectCategory": "Select a category",
  "errorPositiveRate": "Enter a positive exchange rate",
  "exchangeRatePrompt": "1 {currency} = ? {homeCurrency}",
  "@exchangeRatePrompt": {
    "placeholders": {"currency": {"type": "String"}, "homeCurrency": {"type": "String"}}
  }
```

Append to `app/lib/l10n/app_zh.arb`:
```json
  "addExpense": "记一笔",
  "category": "类别",
  "amount": "金额",
  "currency": "币种",
  "description": "备注",
  "date": "日期",
  "statusPlanned": "计划中",
  "statusActual": "已发生",
  "saveExpense": "保存",
  "errorSelectCategory": "请选择类别",
  "errorPositiveRate": "请输入大于0的汇率",
  "exchangeRatePrompt": "1 {currency} = ? {homeCurrency}"
```

Append to `app/lib/l10n/app_de.arb`:
```json
  "addExpense": "Ausgabe hinzufügen",
  "category": "Kategorie",
  "amount": "Betrag",
  "currency": "Währung",
  "description": "Beschreibung",
  "date": "Datum",
  "statusPlanned": "Geplant",
  "statusActual": "Tatsächlich",
  "saveExpense": "Ausgabe speichern",
  "errorSelectCategory": "Kategorie auswählen",
  "errorPositiveRate": "Positiven Wechselkurs eingeben",
  "exchangeRatePrompt": "1 {currency} = ? {homeCurrency}"
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/ui/add_expense_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/add_expense_screen.dart';

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

  Widget wrap() => MaterialApp(
        locale: const Locale('zh'), // tests tap Chinese labels below; pin the locale explicitly
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddExpenseScreen(trip: trip, repository: repo),
      );

  testWidgets('filling a valid home-currency expense saves it as actual by default',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '300');
    await tester.enterText(find.byKey(const Key('expenseDescriptionField')), 'Visa fee');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.length, 1);
    expect(expenses.first.category, 'food');
    expect(expenses.first.amount, Money.fromMajor(300, 'CNY'));
    expect(expenses.first.status, ExpenseStatus.actual);
    expect(expenses.first.paidBy.id, 'p1');
    expect(expenses.first.paidFor.map((p) => p.id).toList(), ['p1']);
  });

  testWidgets('choosing Planned status saves a planned expense', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3200');
    await tester.tap(find.text('计划中'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.status, ExpenseStatus.planned);
    expect(expenses.first.includeInSplit, isTrue);
  });

  testWidgets('an unknown foreign currency prompts for its exchange rate and saves it for reuse',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('住宿').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '10000');
    await tester.enterText(find.byKey(const Key('expenseCurrencyField')), 'JPY');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expenseExchangeRateField')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expenseExchangeRateField')), '0.05');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.amount, Money.fromMajor(10000, 'JPY'));
    expect(expenses.first.amountInHomeCurrency.major, closeTo(500, 0.01));
    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.fromCurrency, 'JPY');
  });

  testWidgets('empty category shows a validation error and does not save', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '30');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    expect(find.text('请选择类别'), findsOneWidget);
    expect(await repo.getExpenses('t1'), isEmpty);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/add_expense_screen_test.dart`
Expected: FAIL — `package:travelspendplus/ui/add_expense_screen.dart` doesn't exist.

- [ ] **Step 4: Implement AddExpenseScreen**

```dart
// app/lib/ui/add_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/exchange_rate.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/money.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'formatting.dart';

class AddExpenseScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  const AddExpenseScreen({super.key, required this.trip, required this.repository});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  final _amountController = TextEditingController();
  late final TextEditingController _currencyController;
  final _descriptionController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  DateTime _date = DateTime.now();
  ExpenseStatus _status = ExpenseStatus.actual;
  List<ExchangeRate> _existingRates = [];

  @override
  void initState() {
    super.initState();
    _currencyController = TextEditingController(text: widget.trip.homeCurrency);
    _currencyController.addListener(() => setState(() {}));
    _loadRates();
  }

  Future<void> _loadRates() async {
    final rates = await widget.repository.getExchangeRates(widget.trip.id);
    if (mounted) setState(() => _existingRates = rates);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _descriptionController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  bool get _needsNewExchangeRate {
    final currency = _currencyController.text.trim().toUpperCase();
    if (currency == widget.trip.homeCurrency || currency.length != 3) return false;
    return !_existingRates.any((r) => r.fromCurrency == currency);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      setState(() {}); // re-run the category FormField's own validator display
      return;
    }

    final currency = _currencyController.text.trim().toUpperCase();
    final amount = Money.fromMajor(double.parse(_amountController.text), currency);

    ExchangeRate? rateToUse;
    if (currency != widget.trip.homeCurrency) {
      rateToUse = _existingRates.firstWhere(
        (r) => r.fromCurrency == currency,
        orElse: () => ExchangeRate(
          fromCurrency: currency,
          toCurrency: widget.trip.homeCurrency,
          rate: double.parse(_exchangeRateController.text),
        ),
      );
      if (_needsNewExchangeRate) {
        await widget.repository.setExchangeRate(widget.trip.id, rateToUse);
      }
    }
    final amountInHomeCurrency = currency == widget.trip.homeCurrency
        ? Money(minorUnits: amount.minorUnits, currencyCode: widget.trip.homeCurrency)
        : rateToUse!.convert(amount);

    final participant = widget.trip.participants.first;
    await widget.repository.addExpense(Expense(
      id: const Uuid().v4(),
      tripId: widget.trip.id,
      category: _category!,
      amount: amount,
      amountInHomeCurrency: amountInHomeCurrency,
      description: _descriptionController.text.trim(),
      date: _date,
      status: _status,
      includeInSplit: true,
      paidBy: participant,
      paidFor: [participant],
    ));
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addExpense)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              key: const Key('expenseCategoryField'),
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.category),
              items: [
                for (final key in kExpenseCategoryKeys)
                  DropdownMenuItem(value: key, child: Text(categoryLabel(context, key))),
              ],
              onChanged: (value) => setState(() => _category = value),
              validator: (value) => value == null ? l10n.errorSelectCategory : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseAmountField'),
              controller: _amountController,
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return (parsed != null && parsed > 0) ? null : l10n.errorPositiveAmount;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseCurrencyField'),
              controller: _currencyController,
              decoration: InputDecoration(labelText: l10n.currency),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_needsNewExchangeRate) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('expenseExchangeRateField'),
                controller: _exchangeRateController,
                decoration: InputDecoration(
                  labelText: l10n.exchangeRatePrompt(
                    _currencyController.text.trim().toUpperCase(),
                    widget.trip.homeCurrency,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  return (parsed != null && parsed > 0) ? null : l10n.errorPositiveRate;
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseDescriptionField'),
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.description),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.date),
              subtitle: Text(formatDate(context, _date)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ExpenseStatus>(
              segments: [
                ButtonSegment(value: ExpenseStatus.planned, label: Text(l10n.statusPlanned)),
                ButtonSegment(value: ExpenseStatus.actual, label: Text(l10n.statusActual)),
              ],
              selected: {_status},
              onSelectionChanged: (selection) => setState(() => _status = selection.first),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('saveExpenseButton'),
              onPressed: _save,
              child: Text(l10n.saveExpense),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/add_expense_screen_test.dart`
Expected: PASS, all 4 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/add_expense_screen.dart test/ui/add_expense_screen_test.dart lib/l10n
git commit -m "Add AddExpenseScreen with inline exchange-rate capture"
```

---

### Task 9: ExchangeRateSettingsScreen

**Files:**
- Create: `app/lib/ui/exchange_rate_settings_screen.dart`
- Test: `app/test/ui/exchange_rate_settings_screen_test.dart`

**Interfaces:**
- Consumes: `Trip`, `ExchangeRate`, `TripRepository.getExchangeRates`, `TripRepository.setExchangeRate`, `TripRepository.changeHomeCurrency` (Task 5), `formatMoney` (Task 2).
- Produces: `ExchangeRateSettingsScreen({required Trip trip, required TripRepository repository})`. Used by Task 10 (`TripDetailScreen`'s settings menu). Test-only `Key`s: `newRateCurrencyField`, `newRateValueField`, `saveRateButton`, `changeCurrencyButton`, `newHomeCurrencyField`, `oldToNewRateField`, `confirmChangeCurrencyButton`.

- [ ] **Step 1: Add this screen's ARB strings**

Append to `app/lib/l10n/app_en.arb`:
```json
  "exchangeRates": "Exchange Rates",
  "addRate": "Add rate",
  "newCurrency": "Currency (3-letter code)",
  "rateValue": "Rate",
  "saveRate": "Save rate",
  "changeHomeCurrency": "Change home currency",
  "newHomeCurrency": "New home currency",
  "oldToNewRateLabel": "1 {oldCurrency} = ? {newCurrency}",
  "@oldToNewRateLabel": {
    "placeholders": {"oldCurrency": {"type": "String"}, "newCurrency": {"type": "String"}}
  },
  "confirmChangeCurrency": "Confirm change",
  "changeCurrencyWarning": "This will rescale the total budget and every expense using the rate you provide."
```

Append to `app/lib/l10n/app_zh.arb`:
```json
  "exchangeRates": "汇率设置",
  "addRate": "添加汇率",
  "newCurrency": "币种(3位代码)",
  "rateValue": "汇率",
  "saveRate": "保存汇率",
  "changeHomeCurrency": "修改本位币",
  "newHomeCurrency": "新本位币",
  "oldToNewRateLabel": "1 {oldCurrency} = ? {newCurrency}",
  "confirmChangeCurrency": "确认修改",
  "changeCurrencyWarning": "会按你填的换算率，重新计算总预算和所有支出的金额。"
```

Append to `app/lib/l10n/app_de.arb`:
```json
  "exchangeRates": "Wechselkurse",
  "addRate": "Kurs hinzufügen",
  "newCurrency": "Währung (3-stelliger Code)",
  "rateValue": "Kurs",
  "saveRate": "Kurs speichern",
  "changeHomeCurrency": "Heimatwährung ändern",
  "newHomeCurrency": "Neue Heimatwährung",
  "oldToNewRateLabel": "1 {oldCurrency} = ? {newCurrency}",
  "confirmChangeCurrency": "Änderung bestätigen",
  "changeCurrencyWarning": "Das Gesamtbudget und alle Ausgaben werden mit dem angegebenen Kurs neu berechnet."
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/ui/exchange_rate_settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
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

  Widget wrap() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExchangeRateSettingsScreen(trip: trip, repository: repo),
      );

  testWidgets('adding a rate persists it and shows it in the list', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newRateCurrencyField')), 'JPY');
    await tester.enterText(find.byKey(const Key('newRateValueField')), '0.05');
    await tester.tap(find.byKey(const Key('saveRateButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('JPY'), findsWidgets);
    final rates = await repo.getExchangeRates('t1');
    expect(rates.length, 1);
    expect(rates.first.rate, 0.05);
  });

  testWidgets('changing home currency rescales the trip and clears the change form',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCurrencyButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('newHomeCurrencyField')), 'JPY');
    await tester.enterText(find.byKey(const Key('oldToNewRateField')), '20');
    await tester.tap(find.byKey(const Key('confirmChangeCurrencyButton')));
    await tester.pumpAndSettle();

    final reloaded = await repo.getTrip('t1');
    expect(reloaded!.homeCurrency, 'JPY');
    expect(reloaded.totalBudget.major, closeTo(20000 * 20, 0.01));
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/exchange_rate_settings_screen_test.dart`
Expected: FAIL — `package:travelspendplus/ui/exchange_rate_settings_screen.dart` doesn't exist.

- [ ] **Step 4: Implement ExchangeRateSettingsScreen**

```dart
// app/lib/ui/exchange_rate_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/exchange_rate.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';

class ExchangeRateSettingsScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  const ExchangeRateSettingsScreen({super.key, required this.trip, required this.repository});

  @override
  State<ExchangeRateSettingsScreen> createState() => _ExchangeRateSettingsScreenState();
}

class _ExchangeRateSettingsScreenState extends State<ExchangeRateSettingsScreen> {
  late Future<List<ExchangeRate>> _ratesFuture;
  final _newRateCurrency = TextEditingController();
  final _newRateValue = TextEditingController();
  bool _showChangeCurrencyForm = false;
  final _newHomeCurrency = TextEditingController();
  final _oldToNewRate = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
  }

  @override
  void dispose() {
    _newRateCurrency.dispose();
    _newRateValue.dispose();
    _newHomeCurrency.dispose();
    _oldToNewRate.dispose();
    super.dispose();
  }

  // A block body, not `=> setState(...)` — an arrow body's implicit return
  // would be the assignment expression's value (a Future, from the async
  // repository call), and Flutter's setState asserts its callback returns
  // void. Caught only by running the widget test, not by reading the code.
  void _refresh() => setState(() {
        _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
      });

  Future<void> _saveRate() async {
    final currency = _newRateCurrency.text.trim().toUpperCase();
    final rate = double.tryParse(_newRateValue.text);
    if (currency.length != 3 || rate == null || rate <= 0) return;
    await widget.repository.setExchangeRate(
      widget.trip.id,
      ExchangeRate(fromCurrency: currency, toCurrency: widget.trip.homeCurrency, rate: rate),
    );
    _newRateCurrency.clear();
    _newRateValue.clear();
    _refresh();
  }

  Future<void> _confirmChangeCurrency() async {
    final newCurrency = _newHomeCurrency.text.trim().toUpperCase();
    final rate = double.tryParse(_oldToNewRate.text);
    if (newCurrency.length != 3 || rate == null || rate <= 0) return;
    await widget.repository.changeHomeCurrency(
      tripId: widget.trip.id,
      newCurrency: newCurrency,
      oldToNewRate: rate,
    );
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exchangeRates)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<ExchangeRate>>(
            future: _ratesFuture,
            builder: (context, snapshot) {
              final rates = snapshot.data ?? [];
              return Column(
                children: [
                  for (final rate in rates)
                    ListTile(
                      title: Text('1 ${rate.fromCurrency} = ${rate.rate} ${rate.toCurrency}'),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          Text(l10n.addRate, style: Theme.of(context).textTheme.titleSmall),
          TextField(
            key: const Key('newRateCurrencyField'),
            controller: _newRateCurrency,
            decoration: InputDecoration(labelText: l10n.newCurrency),
            textCapitalization: TextCapitalization.characters,
          ),
          TextField(
            key: const Key('newRateValueField'),
            controller: _newRateValue,
            decoration: InputDecoration(labelText: l10n.rateValue),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          ElevatedButton(
            key: const Key('saveRateButton'),
            onPressed: _saveRate,
            child: Text(l10n.saveRate),
          ),
          const Divider(height: 32),
          if (!_showChangeCurrencyForm)
            OutlinedButton(
              key: const Key('changeCurrencyButton'),
              onPressed: () => setState(() => _showChangeCurrencyForm = true),
              child: Text(l10n.changeHomeCurrency),
            )
          else ...[
            Text(l10n.changeCurrencyWarning,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextField(
              key: const Key('newHomeCurrencyField'),
              controller: _newHomeCurrency,
              decoration: InputDecoration(labelText: l10n.newHomeCurrency),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              key: const Key('oldToNewRateField'),
              controller: _oldToNewRate,
              decoration: InputDecoration(
                labelText: l10n.oldToNewRateLabel(
                  widget.trip.homeCurrency,
                  _newHomeCurrency.text.trim().isEmpty ? '?' : _newHomeCurrency.text.trim(),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            ElevatedButton(
              key: const Key('confirmChangeCurrencyButton'),
              onPressed: _confirmChangeCurrency,
              child: Text(l10n.confirmChangeCurrency),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/exchange_rate_settings_screen_test.dart`
Expected: PASS, both tests.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/exchange_rate_settings_screen.dart test/ui/exchange_rate_settings_screen_test.dart lib/l10n
git commit -m "Add ExchangeRateSettingsScreen with the reprice-based currency change flow"
```

---

### Task 10: TripDetailScreen

**Files:**
- Create: `app/lib/ui/trip_detail_screen.dart`
- Test: `app/test/ui/trip_detail_screen_test.dart`

**Interfaces:**
- Consumes: `Trip`, `Expense`, `ExpenseStatus`, `ExchangeRate`, `BudgetCalculator.summarize`, `BudgetCalculator.remainingDailyBudget`, `CategoryBreakdownCalculator.breakdown`, `CurrencyConverter.convert` (Task 3), `TripRepository.getTrip`, `TripRepository.getExpenses`, `TripRepository.getExchangeRates`, `TripRepository.updateExpense`, `AppColors` (Task 6), `formatMoney`/`formatDate`/`categoryLabel` (Task 2), `AddExpenseScreen` (Task 8), `ExchangeRateSettingsScreen` (Task 9), `CreateTripScreen` (Task 7, edit mode).
- Produces: `TripDetailScreen({required String tripId, required TripRepository repository})`. Used by Task 11 (`TripListScreen`).

- [ ] **Step 1: Add this screen's ARB strings**

Append to `app/lib/l10n/app_en.arb`:
```json
  "daysUntilDeparture": "{days, plural, =1{1 day until departure} other{{days} days until departure}}",
  "@daysUntilDeparture": {"placeholders": {"days": {"type": "int"}}},
  "tripFinished": "Trip finished",
  "dailyBudgetRemaining": "Daily budget remaining: {amount}/day",
  "@dailyBudgetRemaining": {"placeholders": {"amount": {"type": "String"}}},
  "plannedLabel": "Planned",
  "actualLabel": "Actual",
  "remainingLabel": "Remaining",
  "viewInCurrency": "View in",
  "spendingByCategory": "Spending by category",
  "noExpensesYet": "No expenses yet",
  "expenses": "Expenses",
  "markAsSpent": "Mark as spent",
  "markAsSpentPrompt": "Update the amount if it differs from the estimate, or leave it as is.",
  "confirm": "Confirm",
  "cancel": "Cancel"
```

Append to `app/lib/l10n/app_zh.arb`:
```json
  "daysUntilDeparture": "距出发还有 {days} 天",
  "tripFinished": "行程已结束",
  "dailyBudgetRemaining": "每日剩余预算：{amount}/天",
  "plannedLabel": "计划中",
  "actualLabel": "已发生",
  "remainingLabel": "预计还剩",
  "viewInCurrency": "查看币种",
  "spendingByCategory": "支出分类",
  "noExpensesYet": "还没有记账",
  "expenses": "支出明细",
  "markAsSpent": "标记为已发生",
  "markAsSpentPrompt": "如果实际金额和预估不一样可以在这里改，不改也可以。",
  "confirm": "确认",
  "cancel": "取消"
```

Append to `app/lib/l10n/app_de.arb`:
```json
  "daysUntilDeparture": "{days, plural, =1{1 Tag bis zur Abreise} other{{days} Tage bis zur Abreise}}",
  "tripFinished": "Reise beendet",
  "dailyBudgetRemaining": "Verbleibendes Tagesbudget: {amount}/Tag",
  "plannedLabel": "Geplant",
  "actualLabel": "Tatsächlich",
  "remainingLabel": "Verbleibend",
  "viewInCurrency": "Anzeigen in",
  "spendingByCategory": "Ausgaben nach Kategorie",
  "noExpensesYet": "Noch keine Ausgaben",
  "expenses": "Ausgaben",
  "markAsSpent": "Als ausgegeben markieren",
  "markAsSpentPrompt": "Betrag anpassen, falls er vom Schätzwert abweicht, sonst unverändert lassen.",
  "confirm": "Bestätigen",
  "cancel": "Abbrechen"
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/ui/trip_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/persistence/database.dart' hide Trip, Participant, Expense;
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/add_expense_screen.dart';
import 'package:travelspendplus/ui/trip_detail_screen.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;
  final me = const Participant(id: 'p1', name: 'Me');

  setUp(() {
    db = AppDatabase.memory();
    repo = TripRepository(db);
  });

  tearDown(() async => db.close());

  Widget wrap(String tripId) => MaterialApp(
        locale: const Locale('zh'), // tests tap/assert Chinese labels below; pin the locale explicitly
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripDetailScreen(tripId: tripId, repository: repo),
      );

  testWidgets('a not-yet-departed trip shows a countdown, not a daily budget', (tester) async {
    final farFuture = DateTime.now().add(const Duration(days: 30));
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: farFuture,
      endDate: farFuture.add(const Duration(days: 7)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('30'), findsWidgets);
    expect(find.textContaining('/day'), findsNothing);
  });

  testWidgets('an in-progress trip shows the daily remaining budget', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/day'), findsOneWidget);
  });

  testWidgets('a finished trip shows a static "trip finished" summary', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 20)),
      endDate: DateTime.now().subtract(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.text('行程已结束'), findsOneWidget);
    expect(find.textContaining('/day'), findsNothing);
  });

  testWidgets('an actual expense is reflected in totals and the category chart', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Visa fee',
      date: DateTime.now(),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Visa fee'), findsOneWidget);
  });

  testWidgets('tapping "mark as spent" on a planned expense converts it to actual',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(3200, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(3200, 'CNY'),
      description: 'Flight',
      date: DateTime.now(),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记为已发生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    final expenses = await repo.getExpenses('t1');
    expect(expenses.first.status, ExpenseStatus.actual);
  });

  testWidgets('the FAB navigates to AddExpenseScreen', (tester) async {
    await repo.createTrip(Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(AddExpenseScreen), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/trip_detail_screen_test.dart`
Expected: FAIL — `package:travelspendplus/ui/trip_detail_screen.dart` doesn't exist.

- [ ] **Step 4: Implement TripDetailScreen**

```dart
// app/lib/ui/trip_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/budget_calculator.dart';
import '../domain/category_breakdown.dart';
import '../domain/currency_converter.dart';
import '../domain/exchange_rate.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/money.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'add_expense_screen.dart';
import 'create_trip_screen.dart';
import 'exchange_rate_settings_screen.dart';
import 'formatting.dart';
import 'theme.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final TripRepository repository;
  const TripDetailScreen({super.key, required this.tripId, required this.repository});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailData {
  final Trip trip;
  final List<Expense> expenses;
  final List<ExchangeRate> rates;
  _TripDetailData(this.trip, this.expenses, this.rates);
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<_TripDetailData> _future;
  String? _viewCurrency; // null = show in home currency

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TripDetailData> _load() async {
    final trip = await widget.repository.getTrip(widget.tripId);
    final expenses = await widget.repository.getExpenses(widget.tripId);
    final rates = await widget.repository.getExchangeRates(widget.tripId);
    return _TripDetailData(trip!, expenses, rates);
  }

  // Resets _viewCurrency too, not just _future: if the trip's home currency
  // was changed (via ExchangeRateSettingsScreen) while a non-default
  // _viewCurrency was selected, that currency may no longer have a rate
  // entry relative to the *new* home currency, and CurrencyConverter.convert
  // throws in that case. Matches the design spec's own rule that the
  // currency switch is view-only and resets on navigating away.
  void _refresh() => setState(() {
        _future = _load();
        _viewCurrency = null;
      });

  Future<void> _markAsSpent(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: expense.amount.major.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.markAsSpent),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.markAsSpentPrompt),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirmed != true) return;
    final newAmountMajor = double.tryParse(controller.text) ?? expense.amount.major;
    final newAmount = Money.fromMajor(newAmountMajor, expense.amount.currencyCode);
    final ratio = expense.amount.minorUnits == 0
        ? 1.0
        : newAmount.minorUnits / expense.amount.minorUnits;
    final newAmountInHome = Money(
      minorUnits: (expense.amountInHomeCurrency.minorUnits * ratio).round(),
      currencyCode: expense.amountInHomeCurrency.currencyCode,
    );
    await widget.repository.updateExpense(expense.convertToActual(
      actualAmount: newAmount,
      actualAmountInHomeCurrency: newAmountInHome,
    ));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          FutureBuilder<_TripDetailData>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final trip = snapshot.data!.trip;
              return Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CreateTripScreen(repository: widget.repository, existingTrip: trip),
                    ));
                    _refresh();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.currency_exchange),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExchangeRateSettingsScreen(trip: trip, repository: widget.repository),
                    ));
                    _refresh();
                  },
                ),
              ]);
            },
          ),
        ],
      ),
      body: FutureBuilder<_TripDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final trip = data.trip;
          final expenses = data.expenses;
          final summary = BudgetCalculator.summarize(trip: trip, expenses: expenses);
          final breakdown =
              CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: trip.homeCurrency);
          final displayCurrency = _viewCurrency ?? trip.homeCurrency;

          Money display(Money amount) => displayCurrency == amount.currencyCode
              ? amount
              : CurrencyConverter.convert(
                  amount: amount,
                  toCurrency: displayCurrency,
                  rates: data.rates,
                  homeCurrency: trip.homeCurrency,
                );

          final now = DateTime.now();
          Widget budgetTimingWidget;
          if (now.isBefore(trip.startDate)) {
            final days = trip.startDate.difference(DateTime(now.year, now.month, now.day)).inDays;
            budgetTimingWidget = Chip(label: Text(l10n.daysUntilDeparture(days)));
          } else if (now.isAfter(trip.endDate)) {
            budgetTimingWidget = Chip(label: Text(l10n.tripFinished));
          } else {
            final daily = BudgetCalculator.remainingDailyBudget(
                trip: trip, expenses: expenses, asOf: now);
            budgetTimingWidget = daily == null
                ? const SizedBox.shrink()
                : Text(l10n.dailyBudgetRemaining(formatMoney(display(daily))));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(trip.name, style: Theme.of(context).textTheme.headlineSmall),
              Text('${formatDate(context, trip.startDate)} - ${formatDate(context, trip.endDate)}'),
              const SizedBox(height: 8),
              budgetTimingWidget,
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatMoney(display(summary.totalBudget)),
                              style: Theme.of(context).textTheme.headlineMedium),
                          DropdownButton<String>(
                            value: displayCurrency,
                            underline: const SizedBox.shrink(),
                            items: [
                              trip.homeCurrency,
                              ...data.rates.map((r) => r.fromCurrency),
                            ].toSet().map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (value) => setState(() => _viewCurrency = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _legendItem(context, AppColors.teal, l10n.actualLabel, display(summary.actualTotal)),
                          _legendItem(context, AppColors.gold, l10n.plannedLabel, display(summary.plannedTotal)),
                          _legendItem(context, AppColors.mutedText, l10n.remainingLabel, display(summary.remaining)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (breakdown.isNotEmpty) ...[
                Text(l10n.spendingByCategory, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  height: 180,
                  child: PieChart(PieChartData(sections: [
                    for (var i = 0; i < breakdown.length; i++)
                      PieChartSectionData(
                        value: breakdown[i].total.major,
                        title: '${categoryLabel(context, breakdown[i].category)}\n'
                            '${breakdown[i].percentage.toStringAsFixed(0)}%',
                        radius: 70,
                        color: AppColors.categoryChartColors[
                            kExpenseCategoryKeys.indexOf(breakdown[i].category) %
                                AppColors.categoryChartColors.length],
                      ),
                  ])),
                ),
                const SizedBox(height: 16),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(l10n.noExpensesYet)),
                ),
              Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
              for (final expense in expenses)
                ListTile(
                  title: Text(expense.description.isEmpty
                      ? categoryLabel(context, expense.category)
                      : expense.description),
                  subtitle: Text(categoryLabel(context, expense.category)),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMoney(expense.amount)),
                      if (expense.status == ExpenseStatus.planned)
                        TextButton(
                          onPressed: () => _markAsSpent(expense),
                          child: Text(l10n.markAsSpent, style: const TextStyle(fontSize: 11)),
                        )
                      else
                        Text(l10n.actualLabel, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<_TripDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddExpenseScreen(trip: snapshot.data!.trip, repository: widget.repository),
              ));
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label, Money amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
        Text(formatMoney(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/trip_detail_screen_test.dart`
Expected: PASS, all 6 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/trip_detail_screen.dart test/ui/trip_detail_screen_test.dart lib/l10n
git commit -m "Add TripDetailScreen with 3-state budget card, currency switcher, and pie chart"
```

---

### Task 11: TripListScreen (home screen)

**Files:**
- Create: `app/lib/ui/trip_list_screen.dart`
- Test: `app/test/ui/trip_list_screen_test.dart`

**Interfaces:**
- Consumes: `Trip`, `TripRepository.getAllTrips` (Task 5), `BudgetCalculator.summarize`, `formatMoney`/`formatDate` (Task 2), `CreateTripScreen` (Task 7), `TripDetailScreen` (Task 10).
- Produces: `TripListScreen({required TripRepository repository})`. Used by Task 12 (main.dart) as the app's `home:`.

- [ ] **Step 1: Add this screen's ARB strings**

Append to `app/lib/l10n/app_en.arb`:
```json
  "myTrips": "My Trips",
  "noTripsYet": "No trips yet — tap + to plan your first one",
  "plannedTotal": "Planned",
  "spentTotal": "Spent"
```

Append to `app/lib/l10n/app_zh.arb`:
```json
  "myTrips": "我的行程",
  "noTripsYet": "还没有行程，点右下角开始规划你的第一趟旅行",
  "plannedTotal": "已计划",
  "spentTotal": "已花费"
```

Append to `app/lib/l10n/app_de.arb`:
```json
  "myTrips": "Meine Reisen",
  "noTripsYet": "Noch keine Reisen — tippe auf +, um deine erste zu planen",
  "plannedTotal": "Geplant",
  "spentTotal": "Ausgegeben"
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/ui/trip_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/expense.dart';
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

  testWidgets('shows actual and planned totals separately, not combined into one figure',
      (tester) async {
    await repo.createTrip(Trip(
      id: 't2',
      name: 'Italy Trip',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 12),
      homeCurrency: 'CNY',
      totalBudget: Money.fromMajor(20000, 'CNY'),
      participants: [Participant(id: 'p2', name: 'Me')],
    ));
    final me = Participant(id: 'p2', name: 'Me');
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't2',
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
    await repo.addExpense(Expense(
      id: 'e2',
      tripId: 't2',
      category: 'transport',
      amount: Money.fromMajor(5000, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(5000, 'CNY'),
      description: 'Flight',
      date: DateTime(2026, 10, 7),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    // Distinct actual/planned amounts (300 vs 5000) so a bug that combined
    // them into one "Spent: 5,300" figure would fail both assertions below.
    expect(find.textContaining('300.00'), findsWidgets);
    expect(find.textContaining('5,000.00'), findsWidgets);
    expect(find.textContaining('5,300.00'), findsNothing);
  });

  testWidgets('the FAB navigates to CreateTripScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(CreateTripScreen), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/trip_list_screen_test.dart`
Expected: FAIL — `package:travelspendplus/ui/trip_list_screen.dart` doesn't exist.

- [ ] **Step 4: Implement TripListScreen**

```dart
// app/lib/ui/trip_list_screen.dart
import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/budget_calculator.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'create_trip_screen.dart';
import 'formatting.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  final TripRepository repository;
  const TripListScreen({super.key, required this.repository});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  late Future<List<Trip>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getAllTrips();
  }

  void _refresh() => setState(() => _future = widget.repository.getAllTrips());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myTrips)),
      body: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noTripsYet, textAlign: TextAlign.center),
            ));
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

class _TripCard extends StatelessWidget {
  final Trip trip;
  final TripRepository repository;
  final VoidCallback onReturned;
  const _TripCard({required this.trip, required this.repository, required this.onReturned});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: repository.getExpenses(trip.id),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        final summary = BudgetCalculator.summarize(trip: trip, expenses: expenses);
        // Progress bar reflects total committed spend (actual+planned) against
        // the budget, but actual and planned must be *displayed* separately
        // below — combining them into one "Spent" figure would show unspent,
        // merely-planned money as if it had already been paid (design.md's
        // budget overview explicitly requires showing these two totals apart).
        final committed = summary.actualTotal + summary.plannedTotal;
        final progress = trip.totalBudget.minorUnits == 0
            ? 0.0
            : committed.minorUnits / trip.totalBudget.minorUnits;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripDetailScreen(tripId: trip.id, repository: repository),
                ),
              );
              onReturned();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${formatDate(context, trip.startDate)} - ${formatDate(context, trip.endDate)}'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${l10n.spentTotal} ${formatMoney(summary.actualTotal)}'),
                      Text('${l10n.plannedTotal} ${formatMoney(summary.plannedTotal)}'),
                      Text(formatMoney(trip.totalBudget)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/trip_list_screen_test.dart`
Expected: PASS, all 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/trip_list_screen.dart test/ui/trip_list_screen_test.dart lib/l10n
git commit -m "Add TripListScreen"
```

---

### Task 12: Wire up main.dart

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `buildAppTheme` (Task 6), `TripListScreen` (Task 11), `AppDatabase.openOnDevice` (existing).
- Produces: the real app entry point — `home:` is `TripListScreen` backed by a real on-device `TripRepository`, replacing Task 1's placeholder `Scaffold`.

- [ ] **Step 1: Update the test to match the real entry point**

Replace `app/test/widget_test.dart` entirely:

```dart
// app/test/widget_test.dart
import 'package:flutter/material.dart'; // for Locale — app_localizations.dart imports it but doesn't export it
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `TravelSpendPlusApp` doesn't accept a `repository` parameter yet.

- [ ] **Step 3: Implement the real main.dart**

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import 'persistence/database.dart';
import 'persistence/trip_repository.dart';
import 'ui/theme.dart';
import 'ui/trip_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.openOnDevice();
  runApp(TravelSpendPlusApp(repository: TripRepository(db)));
}

class TravelSpendPlusApp extends StatelessWidget {
  final TripRepository repository;
  const TravelSpendPlusApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: TripListScreen(repository: repository),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: every test file passes — this is the first point all 13 tasks' tests run together; if anything regressed (e.g. a shared ARB key collision), fix it here before moving to Task 13's on-device verification.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "Wire up main.dart: real on-device database, TripListScreen as home"
```

---

### Task 13: Integration test — real on-device persistence and the golden path

**Files:**
- Create: `app/integration_test/golden_path_test.dart`

**Interfaces:**
- Consumes: the whole app (`TravelSpendPlusApp`, Task 12) running against `AppDatabase.openOnDevice()` on a real Android emulator — this is the first test in the entire project (Plan A or B) to exercise that code path instead of `AppDatabase.memory()`.

- [ ] **Step 1: Confirm the Android emulator exists**

```bash
flutter emulators
```

Expected: `travelspend_test` (API 35, `google_apis_playstore`, `arm64-v8a`) is listed. If not present, create it via Android Studio's AVD Manager or `flutter emulators --create --name travelspend_test` followed by configuring the system image to API 35/arm64-v8a in AVD Manager (the CLI create command alone does not let you pick API level/ABI).

Start it and confirm it's visible to Flutter:
```bash
flutter emulators --launch travelspend_test
flutter devices
```
Expected: an Android device entry appears in `flutter devices` output within ~60s of the emulator finishing boot. Note its `<device-id>` for Step 3.

- [ ] **Step 2: Write the integration test**

```dart
// app/integration_test/golden_path_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travelspendplus/main.dart';
import 'package:travelspendplus/persistence/database.dart';
import 'package:travelspendplus/persistence/trip_repository.dart';
import 'package:travelspendplus/ui/trip_detail_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('golden path: create trip -> add planned expense -> mark as spent -> edit expense',
      (tester) async {
    final db = await AppDatabase.openOnDevice();
    final repo = TripRepository(db);
    await tester.pumpWidget(TravelSpendPlusApp(repository: repo));
    await tester.pumpAndSettle();

    // Create a trip.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tripNameField')), 'Golden Path Japan');
    await tester.enterText(find.byKey(const Key('tripBudgetField')), '20000');
    await tester.tap(find.byKey(const Key('saveTripButton')));
    await tester.pumpAndSettle();
    expect(find.text('Golden Path Japan'), findsOneWidget);

    // Open the trip.
    await tester.tap(find.text('Golden Path Japan'));
    await tester.pumpAndSettle();
    expect(find.byType(TripDetailScreen), findsOneWidget);

    // Add a planned expense.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expenseCategoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3200');
    await tester.tap(find.text('计划中'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    // Back on the detail screen: the planned expense shows, mark it as spent.
    expect(find.text('标记为已发生'), findsOneWidget);
    await tester.tap(find.text('标记为已发生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('标记为已发生'), findsNothing);

    // Edit the now-actual expense (added after Task 13 was first written —
    // AddExpenseScreen gained edit mode, opened by tapping the row itself).
    await tester.tap(find.text('交通'));
    await tester.pumpAndSettle();
    expect(find.text('编辑支出'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expenseAmountField')), '3500');
    await tester.tap(find.byKey(const Key('saveExpenseButton')));
    await tester.pumpAndSettle();

    // Verify against the real on-device database directly, not just the UI.
    final trips = await repo.getAllTrips();
    final trip = trips.firstWhere((t) => t.name == 'Golden Path Japan');
    final expenses = await repo.getExpenses(trip.id);
    expect(expenses.single.status.toString(), contains('actual'));
    expect(expenses.single.amount.major, 3500.0);

    await db.close();
  });
}
```

- [ ] **Step 3: Run it on the real emulator**

```bash
flutter test integration_test/golden_path_test.dart -d <device-id>
```

(substitute the device id found in Step 1). Expected: PASS.

**This step must be run and its pass/fail observed directly by whoever is completing this task — not delegated to a subagent's self-report, and not skipped because `flutter analyze`/unit tests are clean.** This is the only test in either Plan A or Plan B that exercises `AppDatabase.openOnDevice()`; a clean static analysis says nothing about whether real sqlite file I/O on a real device actually works.

- [ ] **Step 4: Commit**

```bash
git add integration_test/golden_path_test.dart
git commit -m "Add golden-path integration test, verified on a real Android emulator"
```

---

## Post-implementation

Once all 13 tasks are complete and committed, get a second Fable review of the finished implementation (not just this plan) before considering Plan B done — the user explicitly asked for this as the closing gate, matching how Plan A's acceptance review caught a real reproducible crash bug that static plan review had missed.
