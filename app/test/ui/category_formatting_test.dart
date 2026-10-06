import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/expense_category.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/ui/formatting.dart';

void main() {
  testWidgets('renamed hidden categories keep their label and chosen icon in history', (tester) async {
    const settings = [CategorySetting(key: 'food', displayName: 'Meals', iconKey: 'shopping', hidden: true)];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => Text(categoryLabel(context, 'food', settings: settings))),
    ));
    expect(find.text('Meals'), findsOneWidget);
    expect(categoryIcon('food', settings: settings), Icons.shopping_bag);
    expect(categoryIcon('food', settings: const [CategorySetting(key: 'food', iconKey: 'unknown')]), Icons.restaurant);
  });
}
