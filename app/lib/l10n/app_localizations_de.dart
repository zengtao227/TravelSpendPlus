// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'TravelSpendPlus';

  @override
  String get categoryFood => 'Essen';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryLodging => 'Unterkunft';

  @override
  String get categoryShopping => 'Einkaufen';

  @override
  String get categoryEntertainment => 'Unterhaltung';

  @override
  String get categoryOther => 'Sonstiges';

  @override
  String get newTrip => 'Neue Reise';

  @override
  String get editTrip => 'Reise bearbeiten';

  @override
  String get tripName => 'Reisename';

  @override
  String get startDate => 'Startdatum';

  @override
  String get endDate => 'Enddatum';

  @override
  String get totalBudget => 'Gesamtbudget';

  @override
  String get homeCurrency => 'Heimatwährung';

  @override
  String get createTrip => 'Reise erstellen';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get errorEnterTripName => 'Reisenamen eingeben';

  @override
  String get errorPositiveAmount => 'Positiven Betrag eingeben';

  @override
  String get errorEndDateBeforeStart =>
      'Enddatum darf nicht vor dem Startdatum liegen';

  @override
  String get errorCurrencyCode => '3-stelligen Währungscode eingeben';
}
