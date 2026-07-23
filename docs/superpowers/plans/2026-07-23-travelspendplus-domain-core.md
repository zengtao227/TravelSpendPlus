# TravelSpendPlus Domain Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and fully unit-test TravelSpendPlus's core domain logic and local persistence layer (money/currency math, trip budget math, expense splitting/balances, category breakdown, and a Drift/SQLite persistence layer) — no UI yet. This is Plan A of two; UI screens are a separate follow-up plan built on top of this once it's reviewed.

**Architecture:** Pure-Dart domain layer (`lib/domain/`) with no Flutter/UI/database dependencies, fully unit-testable via `flutter test` with zero emulator/device needed. A thin persistence layer (`lib/persistence/`) using Drift (SQLite) converts between domain objects and database rows. Every task in this plan is TDD: write a failing test, watch it fail, implement, watch it pass.

**Tech Stack:** Flutter (Dart), Drift 2.34.x (SQLite ORM) + sqlite3_flutter_libs 0.5.42 (NOT 0.6.0+eol — see Task 1), build_runner for Drift codegen, uuid for ID generation.

## Global Constraints

- All money is stored and compared as integer minor units (cents) — never `double` for currency amounts — to avoid floating-point rounding bugs. See Task 2.
- Every Flutter/Dart command in this plan runs on the Mac via SSH (`ssh mac "cd ~/TravelSpendPlus/app && <command>"`), never on the Frankfurt VPS directly — Frankfurt is aarch64 Linux and Flutter has no official Linux ARM64 SDK. The Mac already has Flutter 3.44.7, JDK 17, and Android SDK 36 installed and verified (2026-07-23).
- Repo: `https://github.com/zengtao227/TravelSpendPlus`, public, `main` branch. Local clones exist at `/home/opc/TravelSpendPlus` (Frankfurt, docs-only so far) and must be freshly cloned to `~/TravelSpendPlus` on the Mac in Task 1 (does not exist there yet).
- The actual Flutter project (pubspec.yaml, lib/, test/) lives in an `app/` subdirectory of the repo (`TravelSpendPlus/app/`), not the repo root — keeps `docs/` and app code cleanly separated.
- "Splitting" (paid_by / paid_for) only ever splits evenly across participants — no weighted/uneven splits. This is a deliberate scope decision from `docs/design.md` section 1.3, matching TravelSpend's own official behavior (no evidence of uneven splits in their help docs).
- **Deliberately out of scope for this plan** (do not implement): live exchange-rate API fetching + offline rate caching (`docs/design.md` section 2 describes this, but it's a separate network/caching subsystem — this plan implements conversion *math* given a rate, entered manually, not rate *fetching*); any UI/widgets; any platform-specific (Android/iOS) code beyond what `flutter create` scaffolds.
- Money formula source of truth: the "remaining daily budget" worked example in `docs/design.md` has its spent/remaining labels swapped from the real official example — re-verified directly against https://help.travel-spend.com/daily-metrics/.../how-does-the-remaining-daily-budget-work/... on 2026-07-23. **Use these numbers, not the ones narrated in design.md's prose**: 10-day trip, €1000 total budget, 6 days elapsed, **€800 spent, €200 remaining**, 4 days left → €200 ÷ 4 = **€50/day**. The formula itself (`remaining budget ÷ days left`) was already stated correctly in design.md; only the illustrative numbers were mislabeled.

---

### Task 1: Flutter project scaffold

**Files:**
- Create (on the Mac): `~/TravelSpendPlus/` (fresh clone of the repo)
- Create: `~/TravelSpendPlus/app/` (flutter project, via `flutter create`)
- Modify: `~/TravelSpendPlus/app/pubspec.yaml` (add dependencies)

**Interfaces:**
- Produces: a Flutter project at `app/` that `flutter test` and `flutter analyze` run cleanly against (zero tests yet, but the toolchain works end to end). All later tasks assume this exists.

- [ ] **Step 1: Clone the repo onto the Mac**

Run: `ssh mac "cd ~ && git clone https://github.com/zengtao227/TravelSpendPlus.git"`
Expected: `Cloning into 'TravelSpendPlus'...` then success, no errors. If `~/TravelSpendPlus` already exists on the Mac, `cd ~/TravelSpendPlus && git pull` instead.

- [ ] **Step 2: Create the Flutter project inside the repo**

Run:
```
ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus && flutter create --org com.zengtao --project-name travelspendplus app'
```
Expected: `Wrote NNN files.` and no errors. This creates `app/lib/main.dart`, `app/pubspec.yaml`, `app/test/widget_test.dart`, `app/android/`, etc.

- [ ] **Step 3: Add dependencies to pubspec.yaml**

Edit `~/TravelSpendPlus/app/pubspec.yaml` on the Mac (use `ssh mac` with a heredoc, or edit locally and `scp`). Add under `dependencies:`:
```yaml
  drift: ^2.34.2
  sqlite3_flutter_libs: ^0.5.42
  path_provider: ^2.1.6
  uuid: ^4.6.0
```
And under `dev_dependencies:` (alongside the existing `flutter_test`):
```yaml
  drift_dev: ^2.34.5
  build_runner: ^2.15.2
```

**Do not use `sqlite3_flutter_libs: ^0.6.0`** — that version is tagged `+eol` on pub.dev (published 2026-02-15, but the maintainers kept releasing 0.5.x afterward, e.g. 0.5.42 on 2026-03-08) — 0.5.42 is the actually-maintained line, verified against pub.dev's version history directly, not assumed from "latest".

- [ ] **Step 4: Fetch dependencies and verify the toolchain**

Run:
```
ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter pub get'
```
Expected: `Got dependencies!` with no version-resolution errors. If there's a conflict, report the exact error — do not silently downgrade a package without checking why.

- [ ] **Step 5: Verify the default test passes**

Run:
```
ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test'
```
Expected: `00:0X +1: All tests passed!` (the default counter-app widget test that `flutter create` scaffolds).

- [ ] **Step 6: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/ && git commit -m "Scaffold Flutter project, add drift/sqlite/uuid dependencies"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 2: Money value type

**Files:**
- Create: `~/TravelSpendPlus/app/lib/domain/money.dart`
- Test: `~/TravelSpendPlus/app/test/domain/money_test.dart`

**Interfaces:**
- Produces: `class Money { final int minorUnits; final String currencyCode; }` with constructors `Money({required int minorUnits, required String currencyCode})` and `Money.fromMajor(double amount, String currencyCode)`; getter `double get major`; operators `+`, `-`, unary `-`, `<`, `>`, `<=`, `>=`, `==`; `Money dividedBy(int n)`; top-level function `List<Money> splitEvenly(Money total, int parts)`. All later tasks (Trip, Expense, BudgetCalculator, BalanceCalculator) use this type for every currency amount — never a raw `double`.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/domain/money_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';

void main() {
  group('Money construction', () {
    test('fromMajor converts to minor units correctly', () {
      final m = Money.fromMajor(12.34, 'EUR');
      expect(m.minorUnits, 1234);
      expect(m.currencyCode, 'EUR');
    });

    test('major getter converts back to major units', () {
      final m = Money(minorUnits: 1234, currencyCode: 'EUR');
      expect(m.major, closeTo(12.34, 0.001));
    });

    test('fromMajor rounds to the nearest cent', () {
      final m = Money.fromMajor(12.345, 'EUR');
      expect(m.minorUnits, 1235); // rounds half up
    });
  });

  group('Money arithmetic', () {
    test('addition of same currency', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(5.50, 'EUR');
      expect((a + b).minorUnits, 1550);
    });

    test('subtraction of same currency', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(3.00, 'EUR');
      expect((a - b).minorUnits, 700);
    });

    test('addition of different currencies throws', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(10.00, 'USD');
      expect(() => a + b, throwsArgumentError);
    });

    test('unary negation', () {
      final a = Money.fromMajor(10.00, 'EUR');
      expect((-a).minorUnits, -1000);
    });

    test('dividedBy divides toward the nearest cent', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final result = a.dividedBy(4);
      expect(result.minorUnits, 250);
    });
  });

  group('Money comparison', () {
    test('equality is by value', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(10.00, 'EUR');
      expect(a, equals(b));
    });

    test('equality requires same currency', () {
      final a = Money.fromMajor(10.00, 'EUR');
      final b = Money.fromMajor(10.00, 'USD');
      expect(a == b, isFalse);
    });

    test('ordering within same currency', () {
      final a = Money.fromMajor(5.00, 'EUR');
      final b = Money.fromMajor(10.00, 'EUR');
      expect(a < b, isTrue);
      expect(b > a, isTrue);
    });
  });

  group('splitEvenly', () {
    test('splits evenly when divisible with no remainder', () {
      final total = Money.fromMajor(9.00, 'EUR');
      final shares = splitEvenly(total, 3);
      expect(shares.length, 3);
      expect(shares.every((s) => s.minorUnits == 300), isTrue);
    });

    test('distributes the remainder deterministically so shares sum exactly to the total', () {
      // 100 cents / 3 = 33.33..., so shares must be [34, 33, 33] (first N get the extra cent)
      final total = Money(minorUnits: 100, currencyCode: 'EUR');
      final shares = splitEvenly(total, 3);
      expect(shares.map((s) => s.minorUnits), [34, 33, 33]);
      final sum = shares.fold<int>(0, (acc, s) => acc + s.minorUnits);
      expect(sum, 100);
    });

    test('splitting into 1 part returns the whole amount', () {
      final total = Money.fromMajor(50.00, 'EUR');
      final shares = splitEvenly(total, 1);
      expect(shares, [total]);
    });

    test('splitting by zero parts throws', () {
      final total = Money.fromMajor(50.00, 'EUR');
      expect(() => splitEvenly(total, 0), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/money_test.dart'`
Expected: FAIL — `Error: Error when reading 'lib/domain/money.dart': No such file or directory` (or similar "package doesn't exist" compile error, since `lib/domain/money.dart` doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/domain/money.dart`:
```dart
/// Money is always stored as integer minor units (cents) to avoid
/// floating-point rounding errors. Never store currency amounts as `double`.
class Money {
  final int minorUnits;
  final String currencyCode;

  const Money({required this.minorUnits, required this.currencyCode});

  factory Money.fromMajor(double amount, String currencyCode) {
    return Money(minorUnits: (amount * 100).round(), currencyCode: currencyCode);
  }

  double get major => minorUnits / 100;

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'Cannot combine $currencyCode and ${other.currencyCode} directly — convert first',
      );
    }
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -() => Money(minorUnits: -minorUnits, currencyCode: currencyCode);

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  Money dividedBy(int n) {
    if (n == 0) throw ArgumentError('Cannot divide Money by zero');
    return Money.fromMajor(major / n, currencyCode);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits && other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => '${major.toStringAsFixed(2)} $currencyCode';
}

/// Splits [total] into [parts] shares that sum exactly to [total.minorUnits]
/// (unlike naive division, which loses or gains cents to rounding). The
/// first `total.minorUnits % parts` shares get one extra minor unit each —
/// deterministic so the same input always splits the same way, which
/// balance calculations rely on for reproducible net-balance math.
List<Money> splitEvenly(Money total, int parts) {
  if (parts <= 0) {
    throw ArgumentError('parts must be positive, got $parts');
  }
  final base = total.minorUnits ~/ parts;
  final remainder = total.minorUnits % parts;
  return List.generate(parts, (i) {
    final extra = i < remainder ? 1 : 0;
    return Money(minorUnits: base + extra, currencyCode: total.currencyCode);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/money_test.dart'`
Expected: `+15: All tests passed!` (15 test cases across the 4 groups).

- [ ] **Step 5: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/domain/money.dart app/test/domain/money_test.dart && git commit -m "Add Money value type with exact-sum splitEvenly"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 3: ExchangeRate conversion

**Files:**
- Create: `~/TravelSpendPlus/app/lib/domain/exchange_rate.dart`
- Test: `~/TravelSpendPlus/app/test/domain/exchange_rate_test.dart`

**Interfaces:**
- Consumes: `Money` from Task 2 (`Money.fromMajor`, `.currencyCode`, `.major`).
- Produces: `class ExchangeRate { final String fromCurrency; final String toCurrency; final double rate; Money convert(Money amount); }`. Note: `Expense` (Task 4) does NOT reference `ExchangeRate` directly — it just stores whatever `amountInHomeCurrency` it's constructed with. `ExchangeRate.convert()` is the tool a caller (the not-yet-built UI's "add expense" flow) uses to compute that value before constructing the `Expense`. The rate itself isn't persisted anywhere in this plan — see the Global Constraints/exclusions note on `custom_exchange_rate`.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/domain/exchange_rate_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/exchange_rate.dart';

void main() {
  test('converts an amount using the given rate', () {
    final rate = ExchangeRate(fromCurrency: 'USD', toCurrency: 'EUR', rate: 0.92);
    final usd = Money.fromMajor(100.00, 'USD');
    final eur = rate.convert(usd);
    expect(eur.currencyCode, 'EUR');
    expect(eur.major, closeTo(92.00, 0.01));
  });

  test('converting an amount in the wrong currency throws', () {
    final rate = ExchangeRate(fromCurrency: 'USD', toCurrency: 'EUR', rate: 0.92);
    final gbp = Money.fromMajor(100.00, 'GBP');
    expect(() => rate.convert(gbp), throwsArgumentError);
  });

  test('identity rate (same currency) returns an equal amount', () {
    final rate = ExchangeRate(fromCurrency: 'EUR', toCurrency: 'EUR', rate: 1.0);
    final eur = Money.fromMajor(50.00, 'EUR');
    expect(rate.convert(eur), Money.fromMajor(50.00, 'EUR'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/exchange_rate_test.dart'`
Expected: FAIL — compile error, `exchange_rate.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/domain/exchange_rate.dart`:
```dart
import 'money.dart';

/// A conversion rate between two currencies: 1 [fromCurrency] = [rate] [toCurrency].
///
/// Entered manually per-expense for now — live rate fetching with offline
/// caching is a deliberately separate, not-yet-built subsystem (see the
/// implementation plan's Global Constraints).
class ExchangeRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;

  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
  });

  Money convert(Money amount) {
    if (amount.currencyCode != fromCurrency) {
      throw ArgumentError(
        'ExchangeRate is from $fromCurrency, cannot convert ${amount.currencyCode}',
      );
    }
    return Money.fromMajor(amount.major * rate, toCurrency);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/exchange_rate_test.dart'`
Expected: `+3: All tests passed!`

- [ ] **Step 5: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/domain/exchange_rate.dart app/test/domain/exchange_rate_test.dart && git commit -m "Add ExchangeRate conversion"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 4: Core models — Participant, ExpenseStatus, Expense, Trip

**Files:**
- Create: `~/TravelSpendPlus/app/lib/domain/participant.dart`
- Create: `~/TravelSpendPlus/app/lib/domain/expense.dart`
- Create: `~/TravelSpendPlus/app/lib/domain/trip.dart`
- Test: `~/TravelSpendPlus/app/test/domain/expense_test.dart`
- Test: `~/TravelSpendPlus/app/test/domain/trip_test.dart`

**Interfaces:**
- Consumes: `Money` from Task 2.
- Produces:
  - `class Participant { final String id; final String name; }` (equality by `id`).
  - `enum ExpenseStatus { planned, actual }`.
  - `class Expense { final String id; final String tripId; final String category; final Money amount; final Money amountInHomeCurrency; final String description; final DateTime date; final ExpenseStatus status; final bool includeInSplit; final Participant paidBy; final List<Participant> paidFor; Expense copyWith({...}); Expense convertToActual({Money? actualAmount, Money? actualAmountInHomeCurrency}); }` — constructing an `Expense` with `status: ExpenseStatus.actual` and `includeInSplit: false` throws `ArgumentError` (actual expenses always count toward the split ledger).
  - `class Trip { final String id; final String name; final DateTime startDate; final DateTime endDate; final String homeCurrency; final Money totalBudget; final List<Participant> participants; int get totalDays; }` — `totalDays` is inclusive of both start and end dates (a trip from day 1 to day 10 is 10 days, not 9).
- Later tasks (BudgetCalculator, BalanceCalculator, CategoryBreakdownCalculator, persistence layer) all consume these three types.

- [ ] **Step 1: Write the failing tests**

Create `~/TravelSpendPlus/app/test/domain/expense_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/expense.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');
  final bob = Participant(id: 'p2', name: 'Bob');

  Expense makeExpense({ExpenseStatus status = ExpenseStatus.actual, bool includeInSplit = true}) {
    return Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(30.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 3),
      status: status,
      includeInSplit: includeInSplit,
      paidBy: alice,
      paidFor: [alice, bob],
    );
  }

  test('actual expense with includeInSplit=false throws', () {
    expect(
      () => makeExpense(status: ExpenseStatus.actual, includeInSplit: false),
      throwsArgumentError,
    );
  });

  test('actual expense with includeInSplit=true constructs fine', () {
    final e = makeExpense(status: ExpenseStatus.actual, includeInSplit: true);
    expect(e.status, ExpenseStatus.actual);
  });

  test('planned expense can have includeInSplit=false', () {
    final e = makeExpense(status: ExpenseStatus.planned, includeInSplit: false);
    expect(e.includeInSplit, isFalse);
  });

  test('copyWith overrides only the given fields', () {
    final e = makeExpense();
    final updated = e.copyWith(description: 'Lunch instead');
    expect(updated.description, 'Lunch instead');
    expect(updated.amount, e.amount);
    expect(updated.id, e.id);
  });

  test('convertToActual flips status and forces includeInSplit true', () {
    final planned = makeExpense(status: ExpenseStatus.planned, includeInSplit: false);
    final actual = planned.convertToActual();
    expect(actual.status, ExpenseStatus.actual);
    expect(actual.includeInSplit, isTrue);
    expect(actual.amount, planned.amount); // unchanged when no override given
  });

  test('convertToActual can override the amount with the real spent amount', () {
    final planned = makeExpense(status: ExpenseStatus.planned, includeInSplit: false);
    final actual = planned.convertToActual(
      actualAmount: Money.fromMajor(35.00, 'EUR'),
      actualAmountInHomeCurrency: Money.fromMajor(35.00, 'EUR'),
    );
    expect(actual.amount, Money.fromMajor(35.00, 'EUR'));
  });
}
```

Create `~/TravelSpendPlus/app/test/domain/trip_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';

void main() {
  test('totalDays is inclusive of both start and end dates', () {
    final trip = Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(1000.00, 'EUR'),
      participants: [Participant(id: 'p1', name: 'Alice')],
    );
    expect(trip.totalDays, 10);
  });

  test('a single-day trip has totalDays == 1', () {
    final trip = Trip(
      id: 't2',
      name: 'Day trip',
      startDate: DateTime(2026, 3, 5),
      endDate: DateTime(2026, 3, 5),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(100.00, 'EUR'),
      participants: [Participant(id: 'p1', name: 'Alice')],
    );
    expect(trip.totalDays, 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/expense_test.dart test/domain/trip_test.dart'`
Expected: FAIL — compile errors, `participant.dart`/`expense.dart`/`trip.dart` don't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/domain/participant.dart`:
```dart
class Participant {
  final String id;
  final String name;

  const Participant({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Participant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
```

Create `~/TravelSpendPlus/app/lib/domain/expense.dart`:
```dart
import 'money.dart';
import 'participant.dart';

enum ExpenseStatus { planned, actual }

/// A single trip expense — either [ExpenseStatus.planned] (booked/estimated,
/// hasn't happened yet) or [ExpenseStatus.actual] (money already spent).
///
/// Actual expenses always count toward the split ledger (you can't un-split
/// money that's already been spent), so [includeInSplit] must be `true` when
/// [status] is [ExpenseStatus.actual]; for planned expenses it's the user's
/// choice (docs/design.md section 2, confirmed 2026-07-17).
class Expense {
  final String id;
  final String tripId;
  final String category;
  final Money amount;
  final Money amountInHomeCurrency;
  final String description;
  final DateTime date;
  final ExpenseStatus status;
  final bool includeInSplit;
  final Participant paidBy;
  final List<Participant> paidFor;

  Expense({
    required this.id,
    required this.tripId,
    required this.category,
    required this.amount,
    required this.amountInHomeCurrency,
    required this.description,
    required this.date,
    required this.status,
    required this.includeInSplit,
    required this.paidBy,
    required this.paidFor,
  }) {
    if (status == ExpenseStatus.actual && !includeInSplit) {
      throw ArgumentError('Actual expenses must have includeInSplit = true');
    }
  }

  Expense copyWith({
    String? id,
    String? tripId,
    String? category,
    Money? amount,
    Money? amountInHomeCurrency,
    String? description,
    DateTime? date,
    ExpenseStatus? status,
    bool? includeInSplit,
    Participant? paidBy,
    List<Participant>? paidFor,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      amountInHomeCurrency: amountInHomeCurrency ?? this.amountInHomeCurrency,
      description: description ?? this.description,
      date: date ?? this.date,
      status: status ?? this.status,
      includeInSplit: includeInSplit ?? this.includeInSplit,
      paidBy: paidBy ?? this.paidBy,
      paidFor: paidFor ?? this.paidFor,
    );
  }

  /// Marks a planned expense as actually spent. If the real amount differed
  /// from the estimate, pass [actualAmount]/[actualAmountInHomeCurrency] to
  /// update it in the same step — estimate and actual are not forced equal.
  Expense convertToActual({Money? actualAmount, Money? actualAmountInHomeCurrency}) {
    return copyWith(
      status: ExpenseStatus.actual,
      includeInSplit: true,
      amount: actualAmount,
      amountInHomeCurrency: actualAmountInHomeCurrency,
    );
  }
}
```

Create `~/TravelSpendPlus/app/lib/domain/trip.dart`:
```dart
import 'money.dart';
import 'participant.dart';

class Trip {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String homeCurrency;
  final Money totalBudget;
  final List<Participant> participants;

  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.homeCurrency,
    required this.totalBudget,
    required this.participants,
  });

  /// Inclusive of both [startDate] and [endDate] — a trip from day 1 to day
  /// 10 is 10 days, matching how TravelSpend's own daily-budget example
  /// counts trip length.
  int get totalDays => endDate.difference(startDate).inDays + 1;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/expense_test.dart test/domain/trip_test.dart'`
Expected: `+8: All tests passed!` (6 expense tests + 2 trip tests).

- [ ] **Step 5: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/domain/participant.dart app/lib/domain/expense.dart app/lib/domain/trip.dart app/test/domain/expense_test.dart app/test/domain/trip_test.dart && git commit -m "Add Participant, Expense, and Trip domain models"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 5: BudgetCalculator (remaining daily budget)

**Files:**
- Create: `~/TravelSpendPlus/app/lib/domain/budget_calculator.dart`
- Test: `~/TravelSpendPlus/app/test/domain/budget_calculator_test.dart`

**Interfaces:**
- Consumes: `Money`, `Trip`, `Expense`, `ExpenseStatus` from Tasks 2 and 4.
- Produces:
  ```dart
  class BudgetSummary {
    final Money totalBudget;
    final Money plannedTotal;
    final Money actualTotal;
    final Money remaining; // totalBudget - plannedTotal - actualTotal
  }

  class BudgetCalculator {
    static BudgetSummary summarize({required Trip trip, required List<Expense> expenses});

    static Money? remainingDailyBudget({
      required Trip trip,
      required List<Expense> expenses,
      required DateTime asOf,
      bool includePlannedInDailyBudget = true,
    });
  }
  ```
  `remainingDailyBudget` returns `null` if `asOf` is after the trip's last day (no days left to budget for). UI layer (later plan) calls this to drive the "计划中费用是否计入每日预算" toggle via `includePlannedInDailyBudget`.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/domain/budget_calculator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/budget_calculator.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');

  Trip makeTenDayTrip() => Trip(
        id: 't1',
        name: 'Japan',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
        homeCurrency: 'EUR',
        totalBudget: Money.fromMajor(1000.00, 'EUR'),
        participants: [alice],
      );

  Expense actualExpense(double amountEur, DateTime date) => Expense(
        id: 'e-${date.day}',
        tripId: 't1',
        category: 'Food',
        amount: Money.fromMajor(amountEur, 'EUR'),
        amountInHomeCurrency: Money.fromMajor(amountEur, 'EUR'),
        description: 'expense',
        date: date,
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice],
      );

  test('matches the official TravelSpend worked example exactly: '
      '10-day trip, EUR1000 budget, EUR800 spent in the first 6 days, '
      'EUR200 remaining, 4 days left => EUR50/day '
      '(verified 2026-07-23 against help.travel-spend.com directly, '
      'NOT the swapped-label numbers narrated in docs/design.md prose)', () {
    final trip = makeTenDayTrip();
    final expenses = [actualExpense(800.00, DateTime(2026, 1, 3))]; // spent within the first 6 days
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: expenses,
      asOf: DateTime(2026, 1, 7), // start of day 7: 6 days elapsed, 4 remain (7,8,9,10)
    );
    expect(daily, isNotNull);
    expect(daily!.major, closeTo(50.00, 0.01));
  });

  test('returns null once the trip has fully ended', () {
    final trip = makeTenDayTrip();
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: [],
      asOf: DateTime(2026, 1, 11), // day after the trip ends
    );
    expect(daily, isNull);
  });

  test('planned expenses count toward daily budget by default', () {
    final trip = makeTenDayTrip();
    final planned = Expense(
      id: 'e-planned',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(400.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(400.00, 'EUR'),
      description: 'hotel',
      date: DateTime(2026, 1, 9), // a future date within the trip
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice],
    );
    final expenses = [actualExpense(800.00, DateTime(2026, 1, 3)), planned];
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: expenses,
      asOf: DateTime(2026, 1, 7),
    );
    // remaining = 1000 - 800 - 400 = -200 (over budget once the planned hotel is counted)
    expect(daily!.major, closeTo(-50.00, 0.01)); // -200 / 4 days
  });

  test('includePlannedInDailyBudget=false excludes planned expenses', () {
    final trip = makeTenDayTrip();
    final planned = Expense(
      id: 'e-planned',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(400.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(400.00, 'EUR'),
      description: 'hotel',
      date: DateTime(2026, 1, 9),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice],
    );
    final expenses = [actualExpense(800.00, DateTime(2026, 1, 3)), planned];
    final daily = BudgetCalculator.remainingDailyBudget(
      trip: trip,
      expenses: expenses,
      asOf: DateTime(2026, 1, 7),
      includePlannedInDailyBudget: false,
    );
    expect(daily!.major, closeTo(50.00, 0.01)); // planned hotel excluded, same as the base example
  });

  test('summarize totals planned and actual separately', () {
    final trip = makeTenDayTrip();
    final planned = Expense(
      id: 'e-planned',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(400.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(400.00, 'EUR'),
      description: 'hotel',
      date: DateTime(2026, 1, 9),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice],
    );
    final summary = BudgetCalculator.summarize(
      trip: trip,
      expenses: [actualExpense(800.00, DateTime(2026, 1, 3)), planned],
    );
    expect(summary.actualTotal.major, closeTo(800.00, 0.01));
    expect(summary.plannedTotal.major, closeTo(400.00, 0.01));
    expect(summary.remaining.major, closeTo(-200.00, 0.01));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/budget_calculator_test.dart'`
Expected: FAIL — compile error, `budget_calculator.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/domain/budget_calculator.dart`:
```dart
import 'money.dart';
import 'trip.dart';
import 'expense.dart';

class BudgetSummary {
  final Money totalBudget;
  final Money plannedTotal;
  final Money actualTotal;
  final Money remaining;

  const BudgetSummary({
    required this.totalBudget,
    required this.plannedTotal,
    required this.actualTotal,
    required this.remaining,
  });
}

class BudgetCalculator {
  static BudgetSummary summarize({required Trip trip, required List<Expense> expenses}) {
    Money planned = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    Money actual = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    for (final e in expenses) {
      if (e.status == ExpenseStatus.planned) {
        planned = planned + e.amountInHomeCurrency;
      } else {
        actual = actual + e.amountInHomeCurrency;
      }
    }
    return BudgetSummary(
      totalBudget: trip.totalBudget,
      plannedTotal: planned,
      actualTotal: actual,
      remaining: trip.totalBudget - planned - actual,
    );
  }

  /// "What was left of the total budget at the start of [asOf]'s day,
  /// divided by the number of days left" — TravelSpend's own definition.
  /// Only actual expenses dated *before* [asOf]'s day reduce the "at start
  /// of today" remaining amount (today's own actual spending hasn't
  /// happened yet at the moment you check this each morning); planned
  /// expenses count regardless of date when [includePlannedInDailyBudget]
  /// is true, since committed future spending is treated as already
  /// accounted for (docs/design.md section 2).
  static Money? remainingDailyBudget({
    required Trip trip,
    required List<Expense> expenses,
    required DateTime asOf,
    bool includePlannedInDailyBudget = true,
  }) {
    final startOfAsOfDay = DateTime(asOf.year, asOf.month, asOf.day);
    final daysLeft = trip.endDate.difference(startOfAsOfDay).inDays + 1;
    if (daysLeft <= 0) return null;

    Money usedSoFar = Money(minorUnits: 0, currencyCode: trip.homeCurrency);
    for (final e in expenses) {
      final isActualBeforeToday =
          e.status == ExpenseStatus.actual && e.date.isBefore(startOfAsOfDay);
      final isCountedPlanned = e.status == ExpenseStatus.planned && includePlannedInDailyBudget;
      if (isActualBeforeToday || isCountedPlanned) {
        usedSoFar = usedSoFar + e.amountInHomeCurrency;
      }
    }

    final remainingAtStartOfToday = trip.totalBudget - usedSoFar;
    return remainingAtStartOfToday.dividedBy(daysLeft);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/budget_calculator_test.dart'`
Expected: `+5: All tests passed!`

- [ ] **Step 5: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/domain/budget_calculator.dart app/test/domain/budget_calculator_test.dart && git commit -m "Add BudgetCalculator with verified official remaining-daily-budget example"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 6: BalanceCalculator (splitting / net balances)

**Files:**
- Create: `~/TravelSpendPlus/app/lib/domain/balance_calculator.dart`
- Test: `~/TravelSpendPlus/app/test/domain/balance_calculator_test.dart`

**Interfaces:**
- Consumes: `Money`, `splitEvenly` from Task 2; `Participant`, `Expense`, `ExpenseStatus` from Task 4.
- Produces: `class BalanceCalculator { static Map<Participant, Money> netBalances({required List<Expense> expenses, required String homeCurrency}); }`. Positive balance = should receive money; negative = owes money; balances always sum to zero. Only counts expenses where `status == actual` or (`status == planned && includeInSplit == true`) — matches `Expense`'s own invariant that actual is always `includeInSplit: true`, so the filter can simply be `expense.includeInSplit`.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/domain/balance_calculator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/balance_calculator.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');
  final bob = Participant(id: 'p2', name: 'Bob');
  final carol = Participant(id: 'p3', name: 'Carol');

  test('worked 3-person example: Alice pays 90 split 3 ways, '
      'Bob pays 60 split with Alice only => Alice +30, Bob 0, Carol -30', () {
    final expense1 = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(90.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(90.00, 'EUR'),
      description: 'Dinner for 3',
      date: DateTime(2026, 1, 2),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice, bob, carol],
    );
    final expense2 = Expense(
      id: 'e2',
      tripId: 't1',
      category: 'Transport',
      amount: Money.fromMajor(60.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(60.00, 'EUR'),
      description: 'Taxi for 2',
      date: DateTime(2026, 1, 3),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: bob,
      paidFor: [alice, bob],
    );

    final balances = BalanceCalculator.netBalances(
      expenses: [expense1, expense2],
      homeCurrency: 'EUR',
    );

    expect(balances[alice]!.major, closeTo(30.00, 0.01));
    expect(balances[bob]!.major, closeTo(0.00, 0.01));
    expect(balances[carol]!.major, closeTo(-30.00, 0.01));

    final sum = balances.values.fold<int>(0, (acc, m) => acc + m.minorUnits);
    expect(sum, 0, reason: 'net balances must always sum to zero');
  });

  test('planned expense with includeInSplit=false is excluded from balances', () {
    final planned = Expense(
      id: 'e3',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(200.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(200.00, 'EUR'),
      description: 'Hotel deposit',
      date: DateTime(2026, 1, 5),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    final balances = BalanceCalculator.netBalances(expenses: [planned], homeCurrency: 'EUR');
    // A participant who appears only in split-excluded expenses gets no map
    // entry at all (consistent with the "no expenses => empty map" test
    // below) — not a zero-value entry. Checking balances[alice]!  here
    // would throw a null-check error, since alice/bob were never inserted.
    expect(balances.containsKey(alice), isFalse);
    expect(balances.containsKey(bob), isFalse);
  });

  test('planned expense with includeInSplit=true is included in balances', () {
    final planned = Expense(
      id: 'e4',
      tripId: 't1',
      category: 'Hotel',
      amount: Money.fromMajor(200.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(200.00, 'EUR'),
      description: 'Hotel deposit',
      date: DateTime(2026, 1, 5),
      status: ExpenseStatus.planned,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    final balances = BalanceCalculator.netBalances(expenses: [planned], homeCurrency: 'EUR');
    expect(balances[alice]!.major, closeTo(100.00, 0.01));
    expect(balances[bob]!.major, closeTo(-100.00, 0.01));
  });

  test('with no expenses, all known participants are absent (empty map)', () {
    final balances = BalanceCalculator.netBalances(expenses: [], homeCurrency: 'EUR');
    expect(balances, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/balance_calculator_test.dart'`
Expected: FAIL — compile error, `balance_calculator.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/domain/balance_calculator.dart`:
```dart
import 'money.dart';
import 'participant.dart';
import 'expense.dart';

class BalanceCalculator {
  /// Net balance per participant across all expenses that count toward the
  /// split ledger (actual expenses always do; planned expenses only when
  /// `includeInSplit` is true — see Expense's own invariant). Positive means
  /// the participant should receive money; negative means they owe it.
  /// Balances always sum to zero.
  static Map<Participant, Money> netBalances({
    required List<Expense> expenses,
    required String homeCurrency,
  }) {
    final balances = <Participant, Money>{};

    Money zero() => Money(minorUnits: 0, currencyCode: homeCurrency);
    Money current(Participant p) => balances[p] ?? zero();

    for (final expense in expenses) {
      if (!expense.includeInSplit) continue;

      balances[expense.paidBy] = current(expense.paidBy) + expense.amountInHomeCurrency;

      final shares = splitEvenly(expense.amountInHomeCurrency, expense.paidFor.length);
      for (var i = 0; i < expense.paidFor.length; i++) {
        final person = expense.paidFor[i];
        balances[person] = current(person) - shares[i];
      }
    }

    return balances;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/balance_calculator_test.dart'`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/domain/balance_calculator.dart app/test/domain/balance_calculator_test.dart && git commit -m "Add BalanceCalculator for expense-splitting net balances"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 7: CategoryBreakdownCalculator

**Files:**
- Create: `~/TravelSpendPlus/app/lib/domain/category_breakdown.dart`
- Test: `~/TravelSpendPlus/app/test/domain/category_breakdown_test.dart`

**Interfaces:**
- Consumes: `Money`, `Expense`, `ExpenseStatus` from Tasks 2 and 4.
- Produces:
  ```dart
  class CategorySlice {
    final String category;
    final Money total;
    final double percentage; // 0.0-100.0 of the total across all returned slices
  }

  class CategoryBreakdownCalculator {
    static List<CategorySlice> breakdown({
      required List<Expense> expenses,
      required String homeCurrency,
      bool includePlanned = true,
    });
  }
  ```
  Sorted descending by `total`. This feeds the pie chart in the (not-yet-built) UI plan.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/domain/category_breakdown_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/category_breakdown.dart';

void main() {
  final alice = Participant(id: 'p1', name: 'Alice');

  Expense makeExpense(String category, double amount, {ExpenseStatus status = ExpenseStatus.actual}) {
    return Expense(
      id: '$category-$amount',
      tripId: 't1',
      category: category,
      amount: Money.fromMajor(amount, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(amount, 'EUR'),
      description: category,
      date: DateTime(2026, 1, 2),
      status: status,
      includeInSplit: status == ExpenseStatus.actual,
      paidBy: alice,
      paidFor: [alice],
    );
  }

  test('groups by category, sums amounts, computes percentages, '
      'and breaks a tie alphabetically (not left to List.sort\'s '
      'unspecified tie-break order)', () {
    final expenses = [
      makeExpense('Food', 60.00),
      makeExpense('Food', 40.00),
      makeExpense('Transport', 100.00),
    ];
    final slices = CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: 'EUR');

    expect(slices.length, 2);
    // Food (60+40=100) and Transport (100) tie exactly — alphabetically
    // 'Food' < 'Transport', so Food sorts first.
    expect(slices[0].category, 'Food');
    expect(slices[0].total.major, closeTo(100.00, 0.01));
    expect(slices[0].percentage, closeTo(50.0, 0.1));
    expect(slices[1].category, 'Transport');
    expect(slices[1].total.major, closeTo(100.00, 0.01));
    expect(slices[1].percentage, closeTo(50.0, 0.1));
  });

  test('unambiguous sort order when totals differ', () {
    final expenses = [makeExpense('Food', 20.00), makeExpense('Transport', 80.00)];
    final slices = CategoryBreakdownCalculator.breakdown(expenses: expenses, homeCurrency: 'EUR');
    expect(slices[0].category, 'Transport');
    expect(slices[0].percentage, closeTo(80.0, 0.1));
    expect(slices[1].category, 'Food');
    expect(slices[1].percentage, closeTo(20.0, 0.1));
  });

  test('includePlanned=false excludes planned expenses', () {
    final expenses = [
      makeExpense('Food', 50.00, status: ExpenseStatus.actual),
      makeExpense('Hotel', 200.00, status: ExpenseStatus.planned),
    ];
    final slices = CategoryBreakdownCalculator.breakdown(
      expenses: expenses,
      homeCurrency: 'EUR',
      includePlanned: false,
    );
    expect(slices.length, 1);
    expect(slices[0].category, 'Food');
    expect(slices[0].percentage, closeTo(100.0, 0.1));
  });

  test('empty expense list returns empty breakdown', () {
    final slices = CategoryBreakdownCalculator.breakdown(expenses: [], homeCurrency: 'EUR');
    expect(slices, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/category_breakdown_test.dart'`
Expected: FAIL — compile error, `category_breakdown.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/domain/category_breakdown.dart`:
```dart
import 'money.dart';
import 'expense.dart';

class CategorySlice {
  final String category;
  final Money total;
  final double percentage;

  const CategorySlice({required this.category, required this.total, required this.percentage});
}

class CategoryBreakdownCalculator {
  static List<CategorySlice> breakdown({
    required List<Expense> expenses,
    required String homeCurrency,
    bool includePlanned = true,
  }) {
    final totalsByCategory = <String, Money>{};
    for (final e in expenses) {
      if (e.status == ExpenseStatus.planned && !includePlanned) continue;
      final current = totalsByCategory[e.category] ?? Money(minorUnits: 0, currencyCode: homeCurrency);
      totalsByCategory[e.category] = current + e.amountInHomeCurrency;
    }

    if (totalsByCategory.isEmpty) return [];

    final grandTotalMinorUnits =
        totalsByCategory.values.fold<int>(0, (acc, m) => acc + m.minorUnits);

    final slices = totalsByCategory.entries.map((entry) {
      final percentage = grandTotalMinorUnits == 0
          ? 0.0
          : (entry.value.minorUnits / grandTotalMinorUnits) * 100.0;
      return CategorySlice(category: entry.key, total: entry.value, percentage: percentage);
    }).toList();

    slices.sort((a, b) {
      final byTotal = b.total.minorUnits.compareTo(a.total.minorUnits);
      if (byTotal != 0) return byTotal;
      return a.category.compareTo(b.category); // deterministic tie-break, not left to sort-stability luck
    });
    return slices;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/domain/category_breakdown_test.dart'`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/domain/category_breakdown.dart app/test/domain/category_breakdown_test.dart && git commit -m "Add CategoryBreakdownCalculator for spending pie-chart data"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 8: Drift database schema

**Files:**
- Create: `~/TravelSpendPlus/app/lib/persistence/database.dart`
- Test: `~/TravelSpendPlus/app/test/persistence/database_test.dart`

**Interfaces:**
- Produces: `AppDatabase` (Drift database class) with tables `Trips`, `Participants`, `Expenses`, generated via `build_runner` into `database.g.dart`. `AppDatabase.memory()` constructor for tests (in-memory SQLite, no disk I/O). Task 9's `TripRepository` is the only other file allowed to import this — UI code (later plan) goes through the repository, never touches Drift directly.
- **Known simplification, stated explicitly, not hidden:** `Expenses.paidForIds` stores participant IDs as a comma-separated string instead of a proper many-to-many join table. Reasonable for MVP scope (a handful of participants per trip); revisit if trips start having enough participants/expenses that this becomes a real query bottleneck.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/persistence/database_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/persistence/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and read back a trip row', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
          homeCurrency: 'EUR',
          totalBudgetMinorUnits: 100000,
        ));
    final rows = await db.select(db.trips).get();
    expect(rows.length, 1);
    expect(rows.first.name, 'Japan');
    expect(rows.first.totalBudgetMinorUnits, 100000);
  });

  test('can insert a participant referencing a trip', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
          homeCurrency: 'EUR',
          totalBudgetMinorUnits: 100000,
        ));
    await db.into(db.participants).insert(ParticipantsCompanion.insert(
          id: 'p1',
          tripId: 't1',
          name: 'Alice',
        ));
    final rows = await db.select(db.participants).get();
    expect(rows.length, 1);
    expect(rows.first.name, 'Alice');
    expect(rows.first.tripId, 't1');
  });

  test('can insert and read back an expense row', () async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: 'Japan',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
          homeCurrency: 'EUR',
          totalBudgetMinorUnits: 100000,
        ));
    await db.into(db.participants).insert(ParticipantsCompanion.insert(
          id: 'p1',
          tripId: 't1',
          name: 'Alice',
        ));
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e1',
          tripId: 't1',
          category: 'Food',
          amountMinorUnits: 3000,
          amountCurrency: 'EUR',
          amountInHomeCurrencyMinorUnits: 3000,
          description: 'Dinner',
          date: DateTime(2026, 1, 2),
          status: 'actual',
          includeInSplit: true,
          paidById: 'p1',
          paidForIds: 'p1',
        ));
    final rows = await db.select(db.expenses).get();
    expect(rows.length, 1);
    expect(rows.first.category, 'Food');
    expect(rows.first.amountMinorUnits, 3000);
    expect(rows.first.status, 'actual');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/persistence/database_test.dart'`
Expected: FAIL — compile error, `persistence/database.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/persistence/database.dart`:
```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get homeCurrency => text()();
  IntColumn get totalBudgetMinorUnits => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Participants extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// [paidForIds] is a comma-separated list of participant IDs — a deliberate
/// MVP simplification instead of a many-to-many join table. See this
/// plan's Task 8 notes.
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get category => text()();
  IntColumn get amountMinorUnits => integer()();
  TextColumn get amountCurrency => text()();
  IntColumn get amountInHomeCurrencyMinorUnits => integer()();
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => text()(); // 'planned' | 'actual'
  BoolColumn get includeInSplit => boolean()();
  TextColumn get paidById => text().references(Participants, #id)();
  TextColumn get paidForIds => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Trips, Participants, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.memory() : super(NativeDatabase.memory());

  static Future<AppDatabase> openOnDevice() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'travelspendplus.sqlite');
    return AppDatabase(NativeDatabase.createInBackground(File(filePath)));
  }

  @override
  int get schemaVersion => 1;
}
```

`openOnDevice()` isn't exercised by the in-memory tests in this task (no real device/emulator in this plan) but is included now so the persistence layer is genuinely usable once the UI plan wires it up; if `flutter analyze` flags it as unused, that's expected and fine at this stage.

- [ ] **Step 4: Generate Drift code**

Run:
```
ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && dart run build_runner build --delete-conflicting-outputs'
```
Expected: `[INFO] Succeeded after Xs with N outputs` — this generates `lib/persistence/database.g.dart`. Do not hand-write that file.

- [ ] **Step 5: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/persistence/database_test.dart'`
Expected: `+3: All tests passed!`

- [ ] **Step 6: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/persistence/database.dart app/lib/persistence/database.g.dart app/test/persistence/database_test.dart && git commit -m "Add Drift database schema (Trips, Participants, Expenses)"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

### Task 9: TripRepository (persistence <-> domain bridge)

**Files:**
- Create: `~/TravelSpendPlus/app/lib/persistence/trip_repository.dart`
- Test: `~/TravelSpendPlus/app/test/persistence/trip_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` and generated table row/companion classes from Task 8; `Trip`, `Participant`, `Expense`, `ExpenseStatus`, `Money` from Tasks 2 and 4.
- Produces:
  ```dart
  class TripRepository {
    TripRepository(AppDatabase db);
    Future<void> createTrip(Trip trip);
    Future<Trip?> getTrip(String id);
    Future<List<Expense>> getExpenses(String tripId);
    Future<void> addExpense(Expense expense);
    Future<void> updateExpense(Expense expense);
  }
  ```
  This is the only class the (not-yet-built) UI plan is allowed to depend on for data access — it never imports Drift types directly.

- [ ] **Step 1: Write the failing test**

Create `~/TravelSpendPlus/app/test/persistence/trip_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/persistence/database.dart';
import 'package:travelspendplus/persistence/trip_repository.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = TripRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  final alice = Participant(id: 'p1', name: 'Alice');
  final bob = Participant(id: 'p2', name: 'Bob');

  Trip makeTrip() => Trip(
        id: 't1',
        name: 'Japan',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
        homeCurrency: 'EUR',
        totalBudget: Money.fromMajor(1000.00, 'EUR'),
        participants: [alice, bob],
      );

  test('createTrip then getTrip round-trips all fields including participants', () async {
    final trip = makeTrip();
    await repo.createTrip(trip);

    final loaded = await repo.getTrip('t1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Japan');
    expect(loaded.homeCurrency, 'EUR');
    expect(loaded.totalBudget, Money.fromMajor(1000.00, 'EUR'));
    expect(loaded.startDate, DateTime(2026, 1, 1));
    expect(loaded.endDate, DateTime(2026, 1, 10));
    expect(loaded.participants.map((p) => p.name).toSet(), {'Alice', 'Bob'});
  });

  test('getTrip returns null for an unknown id', () async {
    final loaded = await repo.getTrip('nonexistent');
    expect(loaded, isNull);
  });

  test('addExpense then getExpenses round-trips a multi-payer expense', () async {
    await repo.createTrip(makeTrip());
    final expense = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(30.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 2),
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    await repo.addExpense(expense);

    final loaded = await repo.getExpenses('t1');
    expect(loaded.length, 1);
    expect(loaded.first.category, 'Food');
    expect(loaded.first.amount, Money.fromMajor(30.00, 'EUR'));
    expect(loaded.first.paidBy, alice);
    expect(loaded.first.paidFor.map((p) => p.id).toSet(), {'p1', 'p2'});
    expect(loaded.first.status, ExpenseStatus.actual);
  });

  test('updateExpense overwrites an existing expense', () async {
    await repo.createTrip(makeTrip());
    final expense = Expense(
      id: 'e1',
      tripId: 't1',
      category: 'Food',
      amount: Money.fromMajor(30.00, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30.00, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 2),
      status: ExpenseStatus.planned,
      includeInSplit: false,
      paidBy: alice,
      paidFor: [alice, bob],
    );
    await repo.addExpense(expense);

    final actualized = expense.convertToActual(
      actualAmount: Money.fromMajor(35.00, 'EUR'),
      actualAmountInHomeCurrency: Money.fromMajor(35.00, 'EUR'),
    );
    await repo.updateExpense(actualized);

    final loaded = await repo.getExpenses('t1');
    expect(loaded.length, 1);
    expect(loaded.first.status, ExpenseStatus.actual);
    expect(loaded.first.amount, Money.fromMajor(35.00, 'EUR'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/persistence/trip_repository_test.dart'`
Expected: FAIL — compile error, `trip_repository.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `~/TravelSpendPlus/app/lib/persistence/trip_repository.dart`:
```dart
import 'package:drift/drift.dart';

import '../domain/money.dart';
import '../domain/participant.dart';
import '../domain/trip.dart';
import '../domain/expense.dart';
import 'database.dart';

class TripRepository {
  final AppDatabase _db;

  TripRepository(this._db);

  Future<void> createTrip(Trip trip) async {
    await _db.into(_db.trips).insert(TripsCompanion.insert(
          id: trip.id,
          name: trip.name,
          startDate: trip.startDate,
          endDate: trip.endDate,
          homeCurrency: trip.homeCurrency,
          totalBudgetMinorUnits: trip.totalBudget.minorUnits,
        ));
    for (final participant in trip.participants) {
      await _db.into(_db.participants).insert(ParticipantsCompanion.insert(
            id: participant.id,
            tripId: trip.id,
            name: participant.name,
          ));
    }
  }

  Future<Trip?> getTrip(String id) async {
    final tripRow = await (_db.select(_db.trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (tripRow == null) return null;

    final participantRows =
        await (_db.select(_db.participants)..where((p) => p.tripId.equals(id))).get();

    return Trip(
      id: tripRow.id,
      name: tripRow.name,
      startDate: tripRow.startDate,
      endDate: tripRow.endDate,
      homeCurrency: tripRow.homeCurrency,
      totalBudget: Money(minorUnits: tripRow.totalBudgetMinorUnits, currencyCode: tripRow.homeCurrency),
      participants: participantRows
          .map((row) => Participant(id: row.id, name: row.name))
          .toList(),
    );
  }

  // amountInHomeCurrencyMinorUnits has no currency column of its own in the
  // Expenses table (it's always the owning trip's home currency, which
  // doesn't change) — load the trip row once per call and use its
  // homeCurrency directly, instead of guessing from amountCurrency.
  Future<List<Expense>> getExpenses(String tripId) async {
    final tripRow =
        await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (tripRow == null) return [];
    final homeCurrency = tripRow.homeCurrency;

    final expenseRows =
        await (_db.select(_db.expenses)..where((e) => e.tripId.equals(tripId))).get();
    final participantRows =
        await (_db.select(_db.participants)..where((p) => p.tripId.equals(tripId))).get();
    final participantsById = {
      for (final row in participantRows) row.id: Participant(id: row.id, name: row.name),
    };

    return expenseRows.map((row) {
      final paidFor = row.paidForIds.split(',').map((id) => participantsById[id]!).toList();
      return Expense(
        id: row.id,
        tripId: row.tripId,
        category: row.category,
        amount: Money(minorUnits: row.amountMinorUnits, currencyCode: row.amountCurrency),
        amountInHomeCurrency: Money(
          minorUnits: row.amountInHomeCurrencyMinorUnits,
          currencyCode: homeCurrency,
        ),
        description: row.description,
        date: row.date,
        status: row.status == 'actual' ? ExpenseStatus.actual : ExpenseStatus.planned,
        includeInSplit: row.includeInSplit,
        paidBy: participantsById[row.paidById]!,
        paidFor: paidFor,
      );
    }).toList();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.into(_db.expenses).insert(ExpensesCompanion.insert(
          id: expense.id,
          tripId: expense.tripId,
          category: expense.category,
          amountMinorUnits: expense.amount.minorUnits,
          amountCurrency: expense.amount.currencyCode,
          amountInHomeCurrencyMinorUnits: expense.amountInHomeCurrency.minorUnits,
          description: expense.description,
          date: expense.date,
          status: expense.status == ExpenseStatus.actual ? 'actual' : 'planned',
          includeInSplit: expense.includeInSplit,
          paidById: expense.paidBy.id,
          paidForIds: expense.paidFor.map((p) => p.id).join(','),
        ));
  }

  Future<void> updateExpense(Expense expense) async {
    await (_db.update(_db.expenses)..where((e) => e.id.equals(expense.id))).write(
      ExpensesCompanion(
        category: Value(expense.category),
        amountMinorUnits: Value(expense.amount.minorUnits),
        amountCurrency: Value(expense.amount.currencyCode),
        amountInHomeCurrencyMinorUnits: Value(expense.amountInHomeCurrency.minorUnits),
        description: Value(expense.description),
        date: Value(expense.date),
        status: Value(expense.status == ExpenseStatus.actual ? 'actual' : 'planned'),
        includeInSplit: Value(expense.includeInSplit),
        paidById: Value(expense.paidBy.id),
        paidForIds: Value(expense.paidFor.map((p) => p.id).join(',')),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test test/persistence/trip_repository_test.dart'`
Expected: `+4: All tests passed!`

- [ ] **Step 5: Run the full test suite one more time**

Run: `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter test'`
Expected: every test file from Tasks 1-9 passes together (no cross-file naming collisions, no shared-state leakage between `AppDatabase.memory()` instances). Also run `ssh mac 'export PATH="$HOME/development/flutter/bin:$PATH" && cd ~/TravelSpendPlus/app && flutter analyze'` and expect no errors (warnings about the unused `openOnDevice()` are acceptable, see Task 8).

- [ ] **Step 6: Commit**

```
ssh mac 'cd ~/TravelSpendPlus && git add app/lib/persistence/trip_repository.dart app/test/persistence/trip_repository_test.dart && git commit -m "Add TripRepository bridging Drift persistence and domain models"'
ssh mac 'cd ~/TravelSpendPlus && git push origin main'
```

---

## What this plan deliberately does not include

- Any UI/widgets — separate follow-up plan, built on top of `TripRepository` + the `domain/` calculators once this plan is reviewed and merged.
- Live exchange-rate fetching/caching — `ExchangeRate` here only does conversion math given a rate; entering that rate (manually or via a live API) is UI/networking work for later.
- Settlement recording ("mark as settled") — `docs/design.md`'s `Settlement` entity isn't built here; add it alongside the balances UI once that's being designed, since its shape depends on how the balances screen wants to display/act on it.
- Debt-simplification ("minimum number of transactions to settle up") — `docs/design.md` only asks for net balances per person, not an optimal settlement-transaction graph. Don't add this speculatively.
- The exchange rate actually used for a conversion (`custom_exchange_rate` in `docs/design.md`'s data model) is not persisted anywhere — `Expenses` stores only the resulting `amountInHomeCurrencyMinorUnits`, not the rate that produced it. Fine for this plan's math (everything downstream reads `amountInHomeCurrency`), but means a later "what rate did I use for this expense?" display/edit feature needs a schema change, not just new UI. Flagging explicitly per Fable's plan review (2026-07-23) rather than leaving it a silent gap.
- Trip invites / multi-device shared trips (`docs/design.md` section 1.3's "generate an invite link, pull friends in" flow) — `Participant` here is purely local to one device's database, no networking/sync/auth. Out of scope for both this plan and the UI follow-up unless the user asks for it explicitly.
