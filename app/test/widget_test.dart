import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/main.dart';

void main() {
  testWidgets('app builds and resolves a localized title', (tester) async {
    await tester.pumpWidget(const TravelSpendPlusApp());
    await tester.pumpAndSettle();
    expect(find.text('TravelSpendPlus'), findsWidgets);
  });
}
