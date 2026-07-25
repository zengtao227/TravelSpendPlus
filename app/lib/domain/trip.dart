import 'civil_date.dart';
import 'money.dart';
import 'participant.dart';

class Trip {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String homeCurrency;
  final Money totalBudget;
  final List<Participant> participants;

  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.homeCurrency,
    required this.totalBudget,
    required this.participants,
  });

  /// Inclusive of both [startDate] and [endDate] — a trip from day 1 to day
  /// 10 is 10 days, matching how TravelSpend's own daily-budget example
  /// counts trip length. Normalized via [civilDate] so a DST transition
  /// within the trip can't shift a `Duration`-based day count by an hour and
  /// silently floor away a day.
  int get totalDays => civilDate(endDate).difference(civilDate(startDate)).inDays + 1;
}
