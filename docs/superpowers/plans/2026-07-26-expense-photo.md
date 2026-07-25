# Per-Expense Photo Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user attach one photo to any expense, storing it exactly like the existing per-trip photo feature (file-presence-based, no DB column), with the same size cap, and wire it into the UI, the delete flows, and the JSON backup format.

**Architecture:** Copy the proven `TripPhotoStore` pattern to a new `ExpensePhotoStore` keyed by expense id. Wire it into `AddExpenseScreen` (pick/replace/remove UI, identical to `CreateTripScreen`'s photo picker) and into `TripDetailScreen`'s expense list row (a small leading avatar that shows the photo when present, the category icon otherwise). Extend the JSON backup format (`TripBundle`/`backup.dart`) with a per-expense `photo` key and bump `kBackupSchemaVersion`. Add cleanup calls to `TripRepository.deleteExpense`/`deleteTrip` so photo files never become orphaned.

**Tech Stack:** Flutter 3.44.7, `image_picker` (gallery-only), `image` package for resize/re-encode, `path_provider` for the app documents directory, Drift (no schema change needed), existing `flutter_test`/`AppDatabase.memory()` test setup.

## Global Constraints

- One photo per expense, gallery-only picker (no camera) — confirmed with the user via Telegram, 2026-07-25.
- Compression: long side capped at 640px, JPEG quality 80 — identical to `TripPhotoStore`, confirmed with the user.
- No Drift schema migration — photo presence is file-existence-based, exactly like trip photos.
- `kBackupSchemaVersion` bumps from 5 to 6; an older backup missing the new per-expense `photo` key must still import cleanly (defaults to no photo for that expense).
- Any widget test that would paint a real, decodable image via `FileImage`, or directly `await` real file I/O, must be avoided — this project's `flutter_tester` environment hangs indefinitely on that (see `docs/superpowers/specs/2026-07-26-expense-photo-design.md` section 五, and `test/ui/create_trip_screen_test.dart`'s existing comment for the established pattern). Cover that logic with service/repository-level tests instead (no widget tree), and verify the real picker/render interaction manually on the Android emulator.
- Full spec: `docs/superpowers/specs/2026-07-26-expense-photo-design.md`.

---

### Task 1: `ExpensePhotoStore` service

**Files:**
- Create: `app/lib/services/expense_photo_store.dart`
- Test: `app/test/services/expense_photo_store_test.dart`

**Interfaces:**
- Consumes: nothing new (uses `path_provider`, `image`, `dart:io`, `dart:convert` — all already dependencies).
- Produces: `ExpensePhotoStore` with static methods `photoFile(String expenseId) -> Future<File>`, `hasPhoto(String expenseId) -> Future<bool>`, `saveFromPath(String expenseId, String sourcePath) -> Future<void>`, `delete(String expenseId) -> Future<void>`, `readBase64(String expenseId) -> Future<String?>`, `writeBase64(String expenseId, String base64Data) -> Future<void>`, `resetForTesting() -> void`. Later tasks call these directly.

- [ ] **Step 1: Write the failing test**

Create `app/test/services/expense_photo_store_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travelspendplus/services/expense_photo_store.dart';

import '../test_helpers/fake_path_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense_photo_store_test');
    FakePathProviderPlatform.install(tempDir.path);
    ExpensePhotoStore.resetForTesting();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> makeSourceJpeg({int width = 300, int height = 300}) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 100, 50));
    final bytes = img.encodeJpg(image);
    final file = File('${tempDir.path}/source.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('hasPhoto is false before any photo is saved', () async {
    expect(await ExpensePhotoStore.hasPhoto('e1'), isFalse);
  });

  test('saveFromPath then hasPhoto/photoFile round-trips a stored photo', () async {
    final sourcePath = await makeSourceJpeg();
    await ExpensePhotoStore.saveFromPath('e1', sourcePath);

    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);
    final file = await ExpensePhotoStore.photoFile('e1');
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('saveFromPath downsizes an oversized image to the max dimension', () async {
    final sourcePath = await makeSourceJpeg(width: 2000, height: 1000);
    await ExpensePhotoStore.saveFromPath('e1', sourcePath);

    final file = await ExpensePhotoStore.photoFile('e1');
    final decoded = img.decodeImage(await file.readAsBytes())!;
    expect(decoded.width, 640);
    expect(decoded.height, 320);
  });

  test('delete removes a stored photo', () async {
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);

    await ExpensePhotoStore.delete('e1');
    expect(await ExpensePhotoStore.hasPhoto('e1'), isFalse);
  });

  test('delete on an expense with no stored photo does not throw', () async {
    await ExpensePhotoStore.delete('nonexistent');
  });

  test('readBase64 returns null for an expense with no stored photo', () async {
    expect(await ExpensePhotoStore.readBase64('e1'), isNull);
  });

  test('readBase64 then writeBase64 round-trips the exact same bytes to a different expense',
      () async {
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    final originalBytes = await (await ExpensePhotoStore.photoFile('e1')).readAsBytes();

    final base64 = await ExpensePhotoStore.readBase64('e1');
    await ExpensePhotoStore.writeBase64('e2', base64!);

    final copiedBytes = await (await ExpensePhotoStore.photoFile('e2')).readAsBytes();
    expect(copiedBytes, originalBytes);
  });

  test('two different expenses get independent photo files', () async {
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);
    expect(await ExpensePhotoStore.hasPhoto('e2'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (on the Mac, this project has no Flutter toolchain on the VPS):
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/services/expense_photo_store_test.dart
```
Expected: FAIL — `Error: Couldn't resolve the package 'travelspendplus' in 'package:travelspendplus/services/expense_photo_store.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/services/expense_photo_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores one compressed, app-local photo per expense, keyed by expense id.
/// Deliberately not a database column — the file's presence at the
/// deterministic path returned by [photoFile] IS the "does this expense have
/// a photo" state, so nothing else needs to reference it. Identical scheme
/// to TripPhotoStore, just keyed by expense id and a different subdirectory.
class ExpensePhotoStore {
  static const int _maxDimension = 640;
  static const int _jpegQuality = 80;

  static Future<Directory>? _photosDirFuture;

  @visibleForTesting
  static void resetForTesting() {
    _photosDirFuture = null;
  }

  static Future<Directory> _photosDir() {
    return _photosDirFuture ??= () async {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(dir.path, 'expense_photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      return photosDir;
    }();
  }

  static Future<File> photoFile(String expenseId) async {
    final photosDir = await _photosDir();
    return File(p.join(photosDir.path, '$expenseId.jpg'));
  }

  static Future<bool> hasPhoto(String expenseId) async {
    final file = await photoFile(expenseId);
    return file.exists();
  }

  static Future<void> saveFromPath(String expenseId, String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final needsResize = decoded.width > _maxDimension || decoded.height > _maxDimension;
    final resized = needsResize
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? _maxDimension : null,
            height: decoded.height > decoded.width ? _maxDimension : null,
          )
        : decoded;
    final jpg = img.encodeJpg(resized, quality: _jpegQuality);
    final file = await photoFile(expenseId);
    await file.writeAsBytes(jpg);
  }

  static Future<void> delete(String expenseId) async {
    final file = await photoFile(expenseId);
    if (await file.exists()) await file.delete();
  }

  static Future<String?> readBase64(String expenseId) async {
    final file = await photoFile(expenseId);
    if (!await file.exists()) return null;
    return base64Encode(await file.readAsBytes());
  }

  static Future<void> writeBase64(String expenseId, String base64Data) async {
    final file = await photoFile(expenseId);
    await file.writeAsBytes(base64Decode(base64Data));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/services/expense_photo_store_test.dart
```
Expected: PASS, `9 tests passed` (or similar — all tests in the file green, 0 failures).

- [ ] **Step 5: Commit**

```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus" && git add app/lib/services/expense_photo_store.dart app/test/services/expense_photo_store_test.dart && git commit -m "Add ExpensePhotoStore, mirroring TripPhotoStore keyed by expense id"
```

---

### Task 2: Backup format v6 — per-expense photo in `TripBundle`

**Files:**
- Modify: `app/lib/domain/backup.dart`
- Test: `app/test/domain/backup_test.dart`

**Interfaces:**
- Consumes: `TripBundle` (existing, from Task-0/already-shipped trip-photo work), `Expense` (existing domain class, unchanged).
- Produces: `TripBundle.expensePhotosBase64` (`Map<String, String>`, expense id → base64 JPEG, default `const {}`), used by Task 3's repository wiring. `kBackupSchemaVersion` becomes `6`.

- [ ] **Step 1: Write the failing test**

Add to `app/test/domain/backup_test.dart` (append inside `main()`, after the existing `'a trip with no photo omits...'` test):

```dart
  test('expensePhotosBase64 round-trips per expense through tripBundleToJson/tripBundleFromJson',
      () {
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: [makeExpense()],
      exchangeRates: const [],
      expensePhotosBase64: const {'e1': 'ZmFrZSBleHBlbnNlIHBob3Rv'},
    );
    final json = tripBundleToJson(bundle);
    final expenseJson = (json['expenses'] as List).single as Map<String, dynamic>;
    expect(expenseJson['photo'], 'ZmFrZSBleHBlbnNlIHBob3Rv');

    final restored = tripBundleFromJson(json);
    expect(restored.expensePhotosBase64['e1'], 'ZmFrZSBleHBlbnNlIHBob3Rv');
  });

  test('an expense with no photo omits the "photo" key entirely rather than storing null', () {
    final bundle = TripBundle(trip: makeTrip(), expenses: [makeExpense()], exchangeRates: const []);
    final json = tripBundleToJson(bundle);
    final expenseJson = (json['expenses'] as List).single as Map<String, dynamic>;
    expect(expenseJson.containsKey('photo'), isFalse);

    final restored = tripBundleFromJson(json);
    expect(restored.expensePhotosBase64.containsKey('e1'), isFalse);
  });

  test('tripBundleFromJson defaults expensePhotosBase64 to empty for an expense whose "photo" '
      'key is absent (a pre-v6 backup, made before this field existed)', () {
    final json = tripBundleToJson(
      TripBundle(trip: makeTrip(), expenses: [makeExpense()], exchangeRates: const []),
    );
    final restored = tripBundleFromJson(json);
    expect(restored.expensePhotosBase64, isEmpty);
  });

  test('a trip with multiple expenses keeps each one\'s photo keyed by its own id, not mixed up',
      () {
    final secondExpense = makeExpense().copyWith(id: 'e2');
    final bundle = TripBundle(
      trip: makeTrip(),
      expenses: [makeExpense(), secondExpense],
      exchangeRates: const [],
      expensePhotosBase64: const {'e1': 'cGhvdG8gb25l'},
    );
    final restored = tripBundleFromJson(tripBundleToJson(bundle));
    expect(restored.expensePhotosBase64['e1'], 'cGhvdG8gb25l');
    expect(restored.expensePhotosBase64.containsKey('e2'), isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/domain/backup_test.dart
```
Expected: FAIL — `The named parameter 'expensePhotosBase64' isn't defined` (compile error, since `TripBundle` doesn't have that field yet).

- [ ] **Step 3: Write minimal implementation**

In `app/lib/domain/backup.dart`, replace the version-comment block and constant:

```dart
/// v5 added an optional `photo` (base64-encoded JPEG) to each trip bundle.
/// An older backup missing this key still imports fine — `photoBase64`
/// defaults to `null`, meaning no photo.
///
/// v6 added an optional per-expense `photo` (base64-encoded JPEG) inside
/// each expense entry. An older backup missing this key on an expense still
/// imports fine — that expense's entry in `expensePhotosBase64` is simply
/// absent, meaning no photo for that expense.
const int kBackupSchemaVersion = 6;
```

Update the `TripBundle` class:

```dart
class TripBundle {
  final Trip trip;
  final List<Expense> expenses;
  final List<ExchangeRate> exchangeRates;
  final List<String> customCategories;
  final String? photoBase64;
  // Base64-encoded JPEG per expense (already compressed by
  // ExpensePhotoStore), keyed by expense id — absent key means that expense
  // has no stored photo. Same file-has-no-dart:io-dependency split as
  // photoBase64 above: the actual file read/write happens in
  // TripRepository's export/import, not here.
  final Map<String, String> expensePhotosBase64;
  const TripBundle({
    required this.trip,
    required this.expenses,
    required this.exchangeRates,
    this.customCategories = const [],
    this.photoBase64,
    this.expensePhotosBase64 = const {},
  });
}
```

Update `tripBundleToJson`'s expense map to add the per-expense `photo` key:

```dart
    'expenses': bundle.expenses
        .map((e) => {
              'id': e.id,
              'category': e.category,
              'amountMinorUnits': e.amount.minorUnits,
              'amountCurrency': e.amount.currencyCode,
              'amountInHomeCurrencyMinorUnits': e.amountInHomeCurrency.minorUnits,
              'description': e.description,
              'date': dateToBackupString(e.date),
              'endDate': dateToBackupString(e.endDate),
              'location': e.location,
              'excludeFromBreakdown': e.excludeFromBreakdown,
              'status': e.status == ExpenseStatus.actual ? 'actual' : 'planned',
              'includeInSplit': e.includeInSplit,
              'paidById': e.paidBy.id,
              'paidForIds': e.paidFor.map((p) => p.id).toList(),
              if (bundle.expensePhotosBase64[e.id] != null) 'photo': bundle.expensePhotosBase64[e.id],
            })
        .toList(),
```

Update `tripBundleFromJson` to collect the per-expense photos while building the `expenses` list:

```dart
  final expensePhotosBase64 = <String, String>{};
  final expenses = (json['expenses'] as List).cast<Map<String, dynamic>>().map((raw) {
    final paidForIds = (raw['paidForIds'] as List).cast<String>();
    final expenseId = raw['id'] as String;
    final photo = raw['photo'] as String?;
    if (photo != null) expensePhotosBase64[expenseId] = photo;
    return Expense(
      id: expenseId,
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
      endDate: raw['endDate'] != null
          ? dateFromBackupString(raw['endDate'] as String)
          : dateFromBackupString(raw['date'] as String),
      location: raw['location'] as String? ?? '',
      excludeFromBreakdown: raw['excludeFromBreakdown'] as bool? ?? false,
      status: raw['status'] == 'actual' ? ExpenseStatus.actual : ExpenseStatus.planned,
      includeInSplit: raw['includeInSplit'] as bool,
      paidBy: participantsById[raw['paidById'] as String]!,
      paidFor: paidForIds.map((id) => participantsById[id]!).toList(),
    );
  }).toList();
```

And update the `TripBundle(...)` construction at the end of `tripBundleFromJson` to pass it through:

```dart
  return TripBundle(
    trip: trip,
    expenses: expenses,
    exchangeRates: exchangeRates,
    customCategories: customCategories,
    photoBase64: json['photo'] as String?,
    expensePhotosBase64: expensePhotosBase64,
  );
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/domain/backup_test.dart
```
Expected: PASS, every test in the file green (existing tests plus the 4 new ones).

- [ ] **Step 5: Commit**

```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus" && git add app/lib/domain/backup.dart app/test/domain/backup_test.dart && git commit -m "Add per-expense photo to backup format, bump schema version to 6"
```

---

### Task 3: Wire `ExpensePhotoStore` into `TripRepository`

**Files:**
- Modify: `app/lib/persistence/trip_repository.dart`
- Test: `app/test/persistence/trip_repository_test.dart`

**Interfaces:**
- Consumes: `ExpensePhotoStore` (Task 1), `TripBundle.expensePhotosBase64` (Task 2).
- Produces: `TripRepository.deleteExpense`/`deleteTrip` now also clean up expense photo files; `exportAllTripsToJson`/`importAllTripsFromJson` now round-trip expense photos. No signature changes — later tasks (UI) call `ExpensePhotoStore` directly for save/delete on the picker's own save path, and rely on this task only for the delete-cleanup and backup round-trip.

- [ ] **Step 1: Write the failing test**

Add to `app/test/persistence/trip_repository_test.dart`. First, add this import near the top (with the other `services` import):

```dart
import 'package:travelspendplus/services/expense_photo_store.dart';
```

**Also add `ExpensePhotoStore.resetForTesting();` to this file's `setUp()`, right after the existing `TripPhotoStore.resetForTesting();` call (around line 28).** `ExpensePhotoStore` memoizes its resolved documents directory in a static field exactly like `TripPhotoStore` does — without resetting it per test, the second test in this file that saves an expense photo will resolve to the *first* test's already-deleted `photoTempDir` and throw `FileSystemException` on `writeAsBytes`. The `setUp()` block should read:

```dart
  setUp(() async {
    db = AppDatabase.memory();
    repo = TripRepository(db);
    photoTempDir = await Directory.systemTemp.createTemp('trip_repository_test');
    FakePathProviderPlatform.install(photoTempDir.path);
    TripPhotoStore.resetForTesting();
    ExpensePhotoStore.resetForTesting();
  });
```

Then add these tests. Place the first two right after the existing `'deleteTrip removes the trip and every child row...'` test (around line 619), and the photo-round-trip one inside the `group('export/import', () { ... })` block, right after the existing `'exportAllTripsToJson then importAllTripsFromJson round-trips a trip\'s photo'` test:

```dart
  test('deleteExpense removes the expense\'s stored photo', () async {
    await repo.createTrip(makeTrip());
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 3),
      endDate: DateTime(2026, 1, 3),
      location: '',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);

    await repo.deleteExpense('e1');

    expect(await ExpensePhotoStore.hasPhoto('e1'), isFalse);
  });

  test('deleteTrip removes every one of its expenses\' stored photos, not just the trip\'s own',
      () async {
    await repo.createTrip(makeTrip());
    await repo.addExpense(Expense(
      id: 'e1',
      tripId: 't1',
      category: 'food',
      amount: Money.fromMajor(30, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
      description: 'Dinner',
      date: DateTime(2026, 1, 3),
      endDate: DateTime(2026, 1, 3),
      location: '',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));
    await repo.addExpense(Expense(
      id: 'e2',
      tripId: 't1',
      category: 'transport',
      amount: Money.fromMajor(10, 'EUR'),
      amountInHomeCurrency: Money.fromMajor(10, 'EUR'),
      description: 'Bus',
      date: DateTime(2026, 1, 4),
      endDate: DateTime(2026, 1, 4),
      location: '',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: alice,
      paidFor: [alice],
    ));
    await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
    await ExpensePhotoStore.saveFromPath('e2', await makeSourceJpeg());

    await repo.deleteTrip('t1');

    expect(await ExpensePhotoStore.hasPhoto('e1'), isFalse);
    expect(await ExpensePhotoStore.hasPhoto('e2'), isFalse);
  });
```

And this one inside the `group('export/import', ...)` block:

```dart
    test('exportAllTripsToJson then importAllTripsFromJson round-trips an expense\'s photo',
        () async {
      final trip = makeTrip();
      await repo.createTrip(trip);
      await repo.addExpense(Expense(
        id: 'e1',
        tripId: trip.id,
        category: 'food',
        amount: Money.fromMajor(30, 'EUR'),
        amountInHomeCurrency: Money.fromMajor(30, 'EUR'),
        description: 'Dinner',
        date: DateTime(2026, 1, 3),
        endDate: DateTime(2026, 1, 3),
        location: '',
        status: ExpenseStatus.actual,
        includeInSplit: true,
        paidBy: alice,
        paidFor: [alice],
      ));
      await ExpensePhotoStore.saveFromPath('e1', await makeSourceJpeg());
      final originalBytes = await (await ExpensePhotoStore.photoFile('e1')).readAsBytes();

      final json = await repo.exportAllTripsToJson();

      final freshDb = AppDatabase.memory();
      final freshRepo = TripRepository(freshDb);
      await freshRepo.importAllTripsFromJson(json);

      expect(await ExpensePhotoStore.hasPhoto('e1'), isTrue);
      final restoredBytes = await (await ExpensePhotoStore.photoFile('e1')).readAsBytes();
      expect(restoredBytes, originalBytes);

      await freshDb.close();
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/persistence/trip_repository_test.dart
```
Expected: FAIL — the three new tests fail (`deleteExpense`/`deleteTrip` don't clean up expense photos yet, so `hasPhoto` stays `true`; the export/import test finds `hasPhoto` false after import since nothing wrote it).

- [ ] **Step 3: Write minimal implementation**

In `app/lib/persistence/trip_repository.dart`, add the import near the existing `TripPhotoStore` import:

```dart
import '../services/expense_photo_store.dart';
```

Update `deleteExpense`:

```dart
  Future<void> deleteExpense(String expenseId) async {
    await (_db.delete(_db.expenses)..where((e) => e.id.equals(expenseId))).go();
    // Not part of a DB transaction (it's not a DB operation) — mirrors
    // deleteTrip's TripPhotoStore.delete call below.
    await ExpensePhotoStore.delete(expenseId);
  }
```

Update `deleteTrip` to also clean up every child expense's photo. The id snapshot must be taken **inside** the same transaction as the delete, immediately before it — not before `_db.transaction()` starts — otherwise an expense added to this trip in the gap between an outside snapshot and the transaction's `DELETE ... WHERE tripId=...` would be deleted from the DB but never appear in the snapshot, leaving its photo file orphaned:

```dart
  Future<void> deleteTrip(String tripId) async {
    late List<String> expenseIds;
    await _db.transaction(() async {
      // Captured in the same transaction, immediately before the DELETE
      // below — needed afterward to clean up each expense's photo file
      // (not itself a DB operation, so it can't be part of this
      // transaction), and must not be snapshotted outside the transaction
      // or a concurrent insert could be deleted here without its id ever
      // having been captured.
      expenseIds = (await (_db.select(_db.expenses)..where((e) => e.tripId.equals(tripId))).get())
          .map((row) => row.id)
          .toList();
      await (_db.delete(_db.expenses)..where((e) => e.tripId.equals(tripId))).go();
      await (_db.delete(_db.tripExchangeRates)..where((r) => r.tripId.equals(tripId))).go();
      await (_db.delete(_db.tripCategories)..where((c) => c.tripId.equals(tripId))).go();
      await (_db.delete(_db.participants)..where((p) => p.tripId.equals(tripId))).go();
      await (_db.delete(_db.trips)..where((t) => t.id.equals(tripId))).go();
    });
    await TripPhotoStore.delete(tripId);
    for (final expenseId in expenseIds) {
      await ExpensePhotoStore.delete(expenseId);
    }
  }
```

Update `exportAllTripsToJson`:

```dart
  Future<Map<String, dynamic>> exportAllTripsToJson() async {
    final trips = await getAllTrips();
    final bundles = <TripBundle>[];
    for (final trip in trips) {
      final expenses = await getExpenses(trip.id);
      final expensePhotos = <String, String>{};
      for (final expense in expenses) {
        final photo = await ExpensePhotoStore.readBase64(expense.id);
        if (photo != null) expensePhotos[expense.id] = photo;
      }
      bundles.add(TripBundle(
        trip: trip,
        expenses: expenses,
        exchangeRates: await getExchangeRates(trip.id),
        customCategories: await getCustomCategories(trip.id),
        photoBase64: await TripPhotoStore.readBase64(trip.id),
        expensePhotosBase64: expensePhotos,
      ));
    }
    return backupToJson(bundles);
  }
```

Update `importAllTripsFromJson`:

```dart
  Future<int> importAllTripsFromJson(Map<String, dynamic> json) async {
    final bundles = backupFromJson(json);
    for (final bundle in bundles) {
      await createTrip(bundle.trip);
      if (bundle.photoBase64 != null) {
        await TripPhotoStore.writeBase64(bundle.trip.id, bundle.photoBase64!);
      }
      for (final rate in bundle.exchangeRates) {
        await setExchangeRate(bundle.trip.id, rate);
      }
      for (final name in bundle.customCategories) {
        await addCustomCategory(bundle.trip.id, name);
      }
      for (final expense in bundle.expenses) {
        await addExpense(expense);
        final photo = bundle.expensePhotosBase64[expense.id];
        if (photo != null) {
          await ExpensePhotoStore.writeBase64(expense.id, photo);
        }
      }
    }
    return bundles.length;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/persistence/trip_repository_test.dart
```
Expected: PASS, every test in the file green.

- [ ] **Step 5: Run the full test suite to catch any regression**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test
```
Expected: PASS, all tests green (this touches `deleteTrip`, which several other test files exercise indirectly).

- [ ] **Step 6: Commit**

```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus" && git add app/lib/persistence/trip_repository.dart app/test/persistence/trip_repository_test.dart && git commit -m "Wire ExpensePhotoStore into TripRepository delete/export/import"
```

---

### Task 4: `AddExpenseScreen` photo picker UI

**Files:**
- Modify: `app/lib/ui/add_expense_screen.dart`
- Test: `app/test/ui/add_expense_screen_test.dart`

**Interfaces:**
- Consumes: `ExpensePhotoStore` (Task 1).
- Produces: `AddExpenseScreen` gains a `pickImage` constructor parameter (`Future<XFile?> Function()`, same shape as `CreateTripScreen`'s), defaulting to the real gallery picker. No other public signature changes.

- [ ] **Step 1: Write the failing test**

`app/test/ui/add_expense_screen_test.dart` already has a `Widget wrap({Expense? existingExpense, LiveRateService? liveRateService})` helper (defined in its `main()`, using a `trip`/`repo` set up in `setUp()` — it builds `AddExpenseScreen` itself, it does not take a widget argument). Add this test near the end of the file, inside `void main() { ... }`, before the closing brace:

```dart
  testWidgets('with no stored photo, the picker shows the add-photo icon, not a remove button',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    expect(find.byKey(const Key('removeExpensePhotoButton')), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/ui/add_expense_screen_test.dart
```
Expected: FAIL — `Icons.add_a_photo_outlined` not found (no photo picker UI exists yet).

- [ ] **Step 3: Write minimal implementation**

In `app/lib/ui/add_expense_screen.dart`, add imports:

```dart
import 'dart:io';

import 'package:image_picker/image_picker.dart';
```

(add alongside the existing `import 'package:flutter/material.dart';` etc. at the top)

Change the `AddExpenseScreen` class declaration to add the `pickImage` param, matching `CreateTripScreen`'s pattern exactly:

```dart
class AddExpenseScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  final Expense? existingExpense;
  final LiveRateService? liveRateService;
  final Future<XFile?> Function() pickImage;
  AddExpenseScreen({
    super.key,
    required this.trip,
    required this.repository,
    this.existingExpense,
    this.liveRateService,
    Future<XFile?> Function()? pickImage,
  }) : pickImage = pickImage ?? (() => ImagePicker().pickImage(source: ImageSource.gallery));

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}
```

In `_AddExpenseScreenState`, add the photo state fields (alongside the other `late`/nullable fields):

```dart
  String? _pickedPhotoPath;
  bool _removeExistingPhoto = false;
  File? _existingPhotoFile;
```

In `initState`, after `_loadCategories();`, add:

```dart
    if (existing != null) _loadExistingPhoto(existing.id);
```

Add these methods (near `_loadCategories`):

```dart
  Future<void> _loadExistingPhoto(String expenseId) async {
    final has = await ExpensePhotoStore.hasPhoto(expenseId);
    if (!has) return;
    final file = await ExpensePhotoStore.photoFile(expenseId);
    if (mounted) setState(() => _existingPhotoFile = file);
  }

  Future<void> _pickPhoto() async {
    final picked = await widget.pickImage();
    if (picked == null) return;
    setState(() {
      _pickedPhotoPath = picked.path;
      _removeExistingPhoto = false;
    });
  }

  void _clearPhoto() {
    setState(() {
      _pickedPhotoPath = null;
      _removeExistingPhoto = true;
    });
  }

  bool get _showsPhoto =>
      _pickedPhotoPath != null || (_existingPhotoFile != null && !_removeExistingPhoto);

  Widget _buildPhotoPicker() {
    final showsPhoto = _showsPhoto;
    ImageProvider? imageProvider;
    if (_pickedPhotoPath != null) {
      imageProvider = FileImage(File(_pickedPhotoPath!));
    } else if (_existingPhotoFile != null && !_removeExistingPhoto) {
      imageProvider = FileImage(_existingPhotoFile!);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          key: const Key('expensePhotoPicker'),
          onTap: _pickPhoto,
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundImage: imageProvider,
            child: showsPhoto
                ? null
                : Icon(Icons.add_a_photo_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        if (showsPhoto)
          Positioned(
            right: -4,
            top: -4,
            child: GestureDetector(
              key: const Key('removeExpensePhotoButton'),
              onTap: _clearPhoto,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
```

In `_save()`, right after the existing `if (_isEditing) { await widget.repository.updateExpense(expense); } else { await widget.repository.addExpense(expense); }` block, add:

```dart
    if (_pickedPhotoPath != null) {
      await ExpensePhotoStore.saveFromPath(expense.id, _pickedPhotoPath!);
    } else if (_removeExistingPhoto) {
      await ExpensePhotoStore.delete(expense.id);
    }
```

And add the import for `ExpensePhotoStore` alongside the other `../services/` import:

```dart
import '../services/expense_photo_store.dart';
```

In `build()`, add the picker as the first child of the `ListView`'s `children:` list (before the category `InputDecorator`):

```dart
            Center(child: _buildPhotoPicker()),
            const SizedBox(height: 16),
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/ui/add_expense_screen_test.dart
```
Expected: PASS, every test in the file green (existing tests plus the new one).

- [ ] **Step 5: Run `flutter analyze`**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus" && git add app/lib/ui/add_expense_screen.dart app/test/ui/add_expense_screen_test.dart && git commit -m "Add photo picker to AddExpenseScreen"
```

---

### Task 5: Expense list row thumbnail in `TripDetailScreen`

**Files:**
- Modify: `app/lib/ui/trip_detail_screen.dart`
- Test: `app/test/ui/trip_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ExpensePhotoStore` (Task 1), the existing `expense` loop variable in the expense list's `ListView`/`Column` builder (unchanged).
- Produces: a new private `_ExpenseLeadingAvatar` widget, used only within this file — no new public API.

- [ ] **Step 1: Write the failing test**

First, add `ExpensePhotoStore.resetForTesting();` to this file's `setUp()`, right after the existing `TripPhotoStore.resetForTesting();` call (around line 37), and the import `import 'package:travelspendplus/services/expense_photo_store.dart';` near the existing `trip_photo_store.dart` import. This file's tests don't exercise expense photos directly yet, but `ExpensePhotoStore` memoizes its resolved documents directory the same way `TripPhotoStore` does (see Task 3's Step 1 note) — resetting it per test now avoids a latent stale-directory bug for whichever future test first stores an expense photo here.

Then add to `app/test/ui/trip_detail_screen_test.dart`, near the other expense-list tests (after the `'the category legend shows each category name...'` test is a reasonable spot):

```dart
  testWidgets('an expense with no stored photo shows its category icon in the list row',
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
      category: 'food',
      amount: Money.fromMajor(300, 'CNY'),
      amountInHomeCurrency: Money.fromMajor(300, 'CNY'),
      description: 'Dinner',
      date: DateTime.now(),
      endDate: DateTime.now(),
      location: '',
      status: ExpenseStatus.actual,
      includeInSplit: true,
      paidBy: me,
      paidFor: [me],
    ));

    await tester.pumpWidget(wrap('t1'));
    await tester.pumpAndSettle();

    // categoryIcon('food') (app/lib/ui/formatting.dart) returns Icons.restaurant.
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails or passes for the wrong reason**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/ui/trip_detail_screen_test.dart
```
Expected: this specific test PASSES even before Step 3's change (the category icon already renders today) — that's fine, it's a regression guard for the refactor in Step 3, not a new-behavior test. Confirm it passes now, then confirm it still passes after Step 3 (i.e. the swap to `_ExpenseLeadingAvatar` didn't break the no-photo fallback).

- [ ] **Step 3: Implement the leading-avatar widget and wire it in**

In `app/lib/ui/trip_detail_screen.dart`, add the import:

```dart
import '../services/expense_photo_store.dart';
```

Add a new widget class right after the existing `_TripPhotoAvatar` class:

```dart
// A small round avatar for one expense list row: shows the expense's
// stored photo if it has one, the category icon otherwise. Mirrors
// _TripPhotoAvatar's hasPhoto-then-photoFile FutureBuilder shape, just
// falling back to the category icon instead of a zero-size box.
class _ExpenseLeadingAvatar extends StatelessWidget {
  final Expense expense;
  const _ExpenseLeadingAvatar({required this.expense});

  Widget _categoryIconAvatar() => CircleAvatar(
        backgroundColor: AppColors.mutedText.withValues(alpha: 0.15),
        child: Icon(categoryIcon(expense.category), color: AppColors.mutedText),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ExpensePhotoStore.hasPhoto(expense.id),
      builder: (context, snapshot) {
        if (snapshot.data != true) return _categoryIconAvatar();
        return FutureBuilder<File>(
          future: ExpensePhotoStore.photoFile(expense.id),
          builder: (context, fileSnapshot) {
            if (!fileSnapshot.hasData) return _categoryIconAvatar();
            return CircleAvatar(backgroundImage: FileImage(fileSnapshot.data!));
          },
        );
      },
    );
  }
}
```

Replace the `ListTile`'s `leading:` (currently the inline `CircleAvatar(backgroundColor: ..., child: Icon(categoryIcon(expense.category), ...))`) with:

```dart
                    leading: _ExpenseLeadingAvatar(expense: expense),
```

- [ ] **Step 4: Run test to verify it still passes**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test test/ui/trip_detail_screen_test.dart
```
Expected: PASS, every test in the file green, including the Step 1 test.

- [ ] **Step 5: Run the full test suite and analyzer**

Run:
```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus/app" && flutter test && flutter analyze
```
Expected: all tests PASS, `flutter analyze` reports `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd "/Users/zengtao/Doc/My code/TravelSpendPlus" && git add app/lib/ui/trip_detail_screen.dart app/test/ui/trip_detail_screen_test.dart && git commit -m "Show expense photo thumbnail in the trip detail expense list"
```

---

## After all 5 tasks: manual verification (not part of any single task's automated tests)

Per `docs/superpowers/specs/2026-07-26-expense-photo-design.md` section 六 and this project's established release discipline, before shipping:

1. Install a prior real release (e.g. current v1.0.0+9) on the Android emulator, create a real trip with a real expense and a trip photo, then `adb install -r` the new build **without uninstalling** — confirm no data loss and the old trip photo still shows.
2. Add a photo to a new expense, add a photo to an existing expense via edit, replace a photo, remove a photo — confirm each persists correctly and the list thumbnail updates.
3. Run a full JSON backup export, wipe the app, import it back — confirm expense photos come back along with everything else.
4. Delete a single photographed expense, and separately delete an entire trip containing photographed expenses — inspect `adb shell run-as <package> ls files/expense_photos` (or equivalent) to confirm the corresponding files are actually gone, not just the DB rows.
