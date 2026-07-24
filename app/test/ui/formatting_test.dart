import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/ui/formatting.dart';

void main() {
  test('formatMoney includes the currency code and two decimal places', () {
    final result = formatMoney(Money.fromMajor(1234.5, 'EUR'));
    expect(result, contains('EUR'));
    expect(result, contains('1,234.50'));
  });

  test('formatMoney handles a zero amount', () {
    final result = formatMoney(Money(minorUnits: 0, currencyCode: 'USD'));
    expect(result, contains('0.00'));
  });

  testWidgets('categoryLabel resolves the current locale', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(categoryLabel(capturedContext, 'food'), '餐饮');
    expect(categoryLabel(capturedContext, 'transport'), '交通');
  });

  testWidgets('formatDate uses a short readable form', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    expect(formatDate(capturedContext, DateTime(2026, 7, 24)), 'Jul 24, 2026');
  });
}
