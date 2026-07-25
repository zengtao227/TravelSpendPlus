import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/ui/currency_field.dart';

// Ordering of the curated currency list is covered by
// test/domain/currency_list_test.dart (pure, no widget-tree involved).
// Picking an option end-to-end is covered by the real screens that use
// this field (create_trip_screen_test.dart, add_expense_screen_test.dart,
// exchange_rate_settings_screen_test.dart) — Flutter's dropdown menu only
// builds the items near its initial scroll position, and which codes land
// there depends on the button's on-screen position, so asserting on
// specific visible menu items here would just be testing Flutter's
// internal virtualization rather than this widget's own logic.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('a value outside the curated list is shown without crashing (legacy data)',
      (tester) async {
    // Building with an unknown initial value must not hit
    // DropdownButtonFormField's "exactly one item with this value" assertion.
    await tester.pumpWidget(wrap(CurrencyDropdownField(
      fieldKey: const Key('currencyField'),
      value: 'XYZ',
      label: 'Currency',
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('XYZ'), findsOneWidget);
  });
}
