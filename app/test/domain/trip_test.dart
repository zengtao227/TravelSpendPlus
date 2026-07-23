import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';

void main() {
  test('totalDays is inclusive of both start and end dates', () {
    final trip = Trip(
      id: 't1',
      name: 'Japan',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(1000.00, 'EUR'),
      participants: [Participant(id: 'p1', name: 'Alice')],
    );
    expect(trip.totalDays, 10);
  });

  test('a single-day trip has totalDays == 1', () {
    final trip = Trip(
      id: 't2',
      name: 'Day trip',
      startDate: DateTime(2026, 3, 5),
      endDate: DateTime(2026, 3, 5),
      homeCurrency: 'EUR',
      totalBudget: Money.fromMajor(100.00, 'EUR'),
      participants: [Participant(id: 'p1', name: 'Alice')],
    );
    expect(trip.totalDays, 1);
  });
}
