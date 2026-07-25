import 'package:flutter/material.dart';

import '../domain/currency_list.dart';

/// Currency picker used everywhere a currency code is entered (trip home
/// currency, expense currency, exchange-rate currencies) — a dropdown
/// instead of free text so an invalid code can't be typed in. Common
/// currencies (see currency_list.dart) are pinned first, then the rest
/// alphabetically.
class CurrencyDropdownField extends StatelessWidget {
  final Key? fieldKey;
  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  const CurrencyDropdownField({
    super.key,
    this.fieldKey,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Defensive: pre-dropdown data (existing trips/expenses recorded before
    // this change, or anything typed outside kAllCurrencyCodesOrdered) may
    // hold a code that isn't in the curated list. DropdownButtonFormField
    // throws if `value` isn't among `items`, so make sure it always is.
    final codes = kAllCurrencyCodesOrdered.contains(value)
        ? kAllCurrencyCodesOrdered
        : [...kAllCurrencyCodesOrdered, value];
    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [for (final code in codes) DropdownMenuItem(value: code, child: Text(code))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
