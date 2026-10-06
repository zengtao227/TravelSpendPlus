import 'package:flutter_test/flutter_test.dart';
import 'package:travelspendplus/domain/expense.dart';
import 'package:travelspendplus/domain/money.dart';
import 'package:travelspendplus/domain/participant.dart';
import 'package:travelspendplus/domain/trip.dart';
import 'package:travelspendplus/domain/budget_calculator.dart';

void main() {
  const person = Participant(id: 'p1', name: 'Me');
  Expense rental({
    DateTime? start,
    DateTime? end,
    int? pickup = 660,
    int? dropoff = 660,
    int amount = 10001,
  }) => Expense(
    id: 'r1',
    tripId: 't1',
    category: 'transport',
    amount: Money(minorUnits: amount, currencyCode: 'EUR'),
    amountInHomeCurrency: Money(minorUnits: amount, currencyCode: 'EUR'),
    description: 'Car rental',
    date: start ?? DateTime.utc(2026, 10, 1),
    endDate: end ?? DateTime.utc(2026, 10, 2),
    location: '',
    rentalPickupMinutes: pickup,
    rentalReturnMinutes: dropoff,
    status: ExpenseStatus.actual,
    includeInSplit: true,
    paidBy: person,
    paidFor: const [person],
  );
  test('11am to next 11am is one rental day, allocated to pickup day', () {
    final e = rental();
    expect(e.coveredDays, 1);
    expect(dailyExpenseAllocations(e).single.date, DateTime.utc(2026, 10, 1));
    expect(dailyExpenseAllocations(e).single.amount, e.amount);
  });
  test('return before next 11am still counts one day', () {
    expect(rental(dropoff: 659).coveredDays, 1);
  });
  test('one minute after next 11am counts a second rental day', () {
    final e = rental(dropoff: 661);
    expect(e.coveredDays, 2);
    final shares = dailyExpenseAllocations(e);
    expect(shares.map((s) => s.amount.minorUnits), [5001, 5000]);
    expect(shares.last.date, DateTime.utc(2026, 10, 2));
  });
  test('October 1 to October 5 is four rental days', () {
    final e = rental(end: DateTime.utc(2026, 10, 5));
    expect(e.coveredDays, 4);
    expect(dailyExpenseAllocations(e).last.date, DateTime.utc(2026, 10, 4));
  });
  test(
    'seven 24-hour periods have seven shares, no extra return-date share',
    () {
      final e = rental(end: DateTime.utc(2026, 10, 8));
      expect(e.coveredDays, 7);
      final shares = dailyExpenseAllocations(e);
      expect(shares.last.date, DateTime.utc(2026, 10, 7));
      expect(shares.fold<int>(0, (sum, s) => sum + s.amount.minorUnits), 10001);
    },
  );
  test('cross month and wall clock DST dates remain stable', () {
    expect(
      rental(
        start: DateTime(2026, 10, 31),
        end: DateTime(2026, 11, 1),
      ).coveredDays,
      1,
    );
    expect(
      rental(
        start: DateTime(2026, 10, 24),
        end: DateTime(2026, 10, 26),
      ).coveredDays,
      2,
    );
  });
  test(
    'short same-day rental is one day, invalid pairs and duration rejected',
    () {
      expect(
        rental(end: DateTime.utc(2026, 10, 1), dropoff: 720).coveredDays,
        1,
      );
      expect(() => rental(end: DateTime.utc(2026, 10, 1)), throwsArgumentError);
      expect(
        () => rental(end: DateTime.utc(2026, 10, 1), dropoff: 659),
        throwsArgumentError,
      );
      expect(() => rental(pickup: null), throwsArgumentError);
      expect(() => rental(pickup: -1), throwsArgumentError);
      expect(() => rental(dropoff: 1440), throwsArgumentError);
    },
  );
  test(
    'normal transport stays inclusive; copy and actual conversion retain rental times',
    () {
      expect(rental(pickup: null, dropoff: null).coveredDays, 2);
      final e = rental();
      expect(e.copyWith(description: 'Updated').rentalPickupMinutes, 660);
      expect(e.convertToActual().rentalReturnMinutes, 660);
      expect(e.copyWith(clearRentalTimes: true).isCarRental, false);
    },
  );
  test(
    'refund sums remain exact and full trip average uses seven trip days',
    () {
      final e = rental(end: DateTime.utc(2026, 10, 5), amount: -10001);
      expect(
        dailyExpenseAllocations(
          e,
        ).fold<int>(0, (sum, s) => sum + s.amount.minorUnits),
        -10001,
      );
      final trip = Trip(
        id: 't1',
        name: 'Trip',
        startDate: DateTime.utc(2026, 10, 1),
        endDate: DateTime.utc(2026, 10, 7),
        homeCurrency: 'EUR',
        totalBudget: Money.fromMajor(1000, 'EUR'),
        participants: const [person],
      );
      expect(
        BudgetCalculator.averageDailySpendForTrip(
          trip: trip,
          expenses: [rental(amount: 70000)],
        ).minorUnits,
        10000,
      );
    },
  );
}
