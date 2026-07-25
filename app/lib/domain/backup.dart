import 'package:csv/csv.dart';

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
///
/// v2 added `customCategories` to each trip bundle. A v1 backup (no such
/// key) still imports fine — `tripBundleFromJson` defaults it to an empty
/// list — this bump only blocks a v2 (or later) backup from being read by
/// an app that doesn't know about the newer field yet.
///
/// v3 added `endDate` and `location` to each expense. An older backup
/// missing either key still imports fine — `endDate` defaults to the
/// expense's own `date`, `location` defaults to `''`.
///
/// v4 added `excludeFromBreakdown` to each expense. An older backup missing
/// this key still imports fine — it defaults to `false`.
const int kBackupSchemaVersion = 4;

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
  final List<String> customCategories;
  const TripBundle({
    required this.trip,
    required this.expenses,
    required this.exchangeRates,
    this.customCategories = const [],
  });
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
              'endDate': dateToBackupString(e.endDate),
              'location': e.location,
              'excludeFromBreakdown': e.excludeFromBreakdown,
              'status': e.status == ExpenseStatus.actual ? 'actual' : 'planned',
              'includeInSplit': e.includeInSplit,
              'paidById': e.paidBy.id,
              'paidForIds': e.paidFor.map((p) => p.id).toList(),
            })
        .toList(),
    'exchangeRates':
        bundle.exchangeRates.map((r) => {'fromCurrency': r.fromCurrency, 'rate': r.rate}).toList(),
    'customCategories': bundle.customCategories,
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
      // Absent in a pre-v3 backup — default to the same day (endDate) and
      // no location, matching how a pre-migration DB row reads too.
      endDate: raw['endDate'] != null
          ? dateFromBackupString(raw['endDate'] as String)
          : dateFromBackupString(raw['date'] as String),
      location: raw['location'] as String? ?? '',
      // Absent in a pre-v4 backup — default to false, matching how a
      // pre-migration DB row reads too.
      excludeFromBreakdown: raw['excludeFromBreakdown'] as bool? ?? false,
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

  // Absent in a v1 backup (customCategories didn't exist yet) — default to
  // empty rather than requiring the key, so old backups still import.
  final customCategories = (json['customCategories'] as List?)?.cast<String>() ?? const [];

  return TripBundle(
    trip: trip,
    expenses: expenses,
    exchangeRates: exchangeRates,
    customCategories: customCategories,
  );
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
      dateToBackupString(e.endDate),
      categoryLabel(e.category),
      statusLabel(e.status),
      e.description,
      e.location,
      e.amount.major.toStringAsFixed(2),
      e.amount.currencyCode,
      e.amountInHomeCurrency.major.toStringAsFixed(2),
    ]);
  }
  // `csv` is this package's default top-level `Csv()` instance (csv 8.x
  // redesigned the API away from the older `ListToCsvConverter` class).
  return csv.encode(rows);
}
