// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TravelSpendPlus';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryLodging => 'Lodging';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryOther => 'Other';

  @override
  String get newTrip => 'New Trip';

  @override
  String get editTrip => 'Edit Trip';

  @override
  String get tripName => 'Trip name';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get totalBudget => 'Total budget';

  @override
  String get homeCurrency => 'Home currency';

  @override
  String get createTrip => 'Create Trip';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get errorEnterTripName => 'Enter a trip name';

  @override
  String get errorPositiveAmount => 'Enter a positive amount';

  @override
  String get errorEndDateBeforeStart =>
      'End date must be on or after the start date';

  @override
  String get errorCurrencyCode => 'Enter a 3-letter currency code';
}
