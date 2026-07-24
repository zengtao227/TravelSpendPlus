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

  @override
  String get addExpense => 'Ausgabe hinzufügen';

  @override
  String get category => 'Kategorie';

  @override
  String get amount => 'Betrag';

  @override
  String get currency => 'Währung';

  @override
  String get description => 'Beschreibung';

  @override
  String get date => 'Datum';

  @override
  String get statusPlanned => 'Geplant';

  @override
  String get statusActual => 'Tatsächlich';

  @override
  String get saveExpense => 'Ausgabe speichern';

  @override
  String get errorSelectCategory => 'Kategorie auswählen';

  @override
  String get errorPositiveRate => 'Positiven Wechselkurs eingeben';

  @override
  String exchangeRatePrompt(String currency, String homeCurrency) {
    return '1 $currency = ? $homeCurrency';
  }

  @override
  String get exchangeRates => 'Wechselkurse';

  @override
  String get addRate => 'Kurs hinzufügen';

  @override
  String get newCurrency => 'Währung (3-stelliger Code)';

  @override
  String get rateValue => 'Kurs';

  @override
  String get saveRate => 'Kurs speichern';

  @override
  String get changeHomeCurrency => 'Heimatwährung ändern';

  @override
  String get newHomeCurrency => 'Neue Heimatwährung';

  @override
  String oldToNewRateLabel(String oldCurrency, String newCurrency) {
    return '1 $oldCurrency = ? $newCurrency';
  }

  @override
  String get confirmChangeCurrency => 'Änderung bestätigen';

  @override
  String get changeCurrencyWarning =>
      'Das Gesamtbudget und alle Ausgaben werden mit dem angegebenen Kurs neu berechnet.';
}
