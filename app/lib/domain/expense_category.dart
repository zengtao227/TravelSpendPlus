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
