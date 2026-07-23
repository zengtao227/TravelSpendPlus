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
  /// counts trip length.
  int get totalDays => endDate.difference(startDate).inDays + 1;
}
