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
