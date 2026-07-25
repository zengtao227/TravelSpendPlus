/// The fixed set of built-in expense categories, available in every trip.
/// `Expense.category` stores one of these lowercase keys, or a per-trip
/// custom category name typed by the user (see `persistence/database.dart`'s
/// TripCategories table) — built-in keys are localized via `categoryLabel()`
/// (`lib/ui/formatting.dart`) so category statistics don't fragment across
/// languages; custom categories have no translation and display as typed.
const List<String> kExpenseCategoryKeys = [
  'flight',
  'lodging',
  'food',
  'transport',
  'shopping',
  'entertainment',
  'other',
];
