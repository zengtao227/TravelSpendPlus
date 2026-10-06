import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/money.dart';
import '../domain/expense_category.dart';

String formatMoney(Money money) {
  final format = NumberFormat.currency(symbol: '${money.currencyCode} ', decimalDigits: 2);
  return format.format(money.major);
}

String formatDate(BuildContext context, DateTime date) {
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
}

/// Localizes one of the fixed built-in category keys; a custom category
/// (anything else — see `persistence/database.dart`'s TripCategories table)
/// has no translation to look up and is already user-typed display text,
/// so it's returned as-is.
String categoryLabel(BuildContext context, String key, {List<CategorySetting> settings = const []}) {
  for (final setting in settings) {
    if (setting.key == key && setting.displayName != null) return setting.displayName!;
  }
  final l10n = AppLocalizations.of(context)!;
  switch (key) {
    case 'food':
      return l10n.categoryFood;
    case 'drinks':
      return l10n.categoryDrinks;
    case 'transport':
      return l10n.categoryTransport;
    case 'flight':
      return l10n.categoryFlight;
    case 'lodging':
      return l10n.categoryLodging;
    case 'shopping':
      return l10n.categoryShopping;
    case 'entertainment':
      return l10n.categoryEntertainment;
    case 'sightseeing':
      return l10n.categorySightseeing;
    case 'other':
      return l10n.categoryOther;
    default:
      return key;
  }
}

/// Icon for one of the fixed built-in category keys; a custom category has
/// no dedicated icon, so it falls back to a generic label icon.
IconData categoryIcon(String key, {List<CategorySetting> settings = const []}) {
  for (final setting in settings) {
    if (setting.key == key && kCategoryIconChoices.containsKey(setting.iconKey)) {
      return kCategoryIconChoices[setting.iconKey]!;
    }
  }
  switch (key) {
    case 'food':
      return Icons.restaurant;
    case 'drinks':
      return Icons.local_cafe;
    case 'transport':
      return Icons.directions_bus;
    case 'flight':
      return Icons.flight;
    case 'lodging':
      return Icons.hotel;
    case 'shopping':
      return Icons.shopping_bag;
    case 'entertainment':
      return Icons.local_activity;
    case 'sightseeing':
      return Icons.photo_camera_outlined;
    case 'other':
      return Icons.category;
    default:
      return Icons.label;
  }
}

// Static icon references keep release builds compatible with icon tree shaking.
const Map<String, IconData> kCategoryIconChoices = {
  'food': Icons.restaurant,
  'drinks': Icons.local_cafe,
  'transport': Icons.directions_bus,
  'flight': Icons.flight,
  'lodging': Icons.hotel,
  'shopping': Icons.shopping_bag,
  'entertainment': Icons.local_activity,
  'sightseeing': Icons.photo_camera_outlined,
  'other': Icons.category,
  'car': Icons.directions_car,
  'train': Icons.train,
  'fuel': Icons.local_gas_station,
  'health': Icons.local_hospital,
  'beach': Icons.beach_access,
  'hiking': Icons.hiking,
  'groceries': Icons.local_grocery_store,
  'tickets': Icons.confirmation_number,
  'parking': Icons.local_parking,
  'gifts': Icons.card_giftcard,
  'label': Icons.label,
};
