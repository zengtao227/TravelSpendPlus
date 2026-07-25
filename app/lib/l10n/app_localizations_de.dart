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
  String get categoryFlight => 'Flug';

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
  String get trackBudget => 'Budget verfolgen';

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
  String get addExpense => 'Ausgabe hinzufügen';

  @override
  String get editExpense => 'Ausgabe bearbeiten';

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
  String get addCategory => 'Kategorie hinzufügen';

  @override
  String get categoryName => 'Kategoriename';

  @override
  String get errorEnterCategoryName => 'Kategorienamen eingeben';

  @override
  String get errorDuplicateCategory => 'Diese Kategorie gibt es schon';

  @override
  String get errorPositiveRate => 'Positiven Wechselkurs eingeben';

  @override
  String exchangeRatePrompt(String currency, String homeCurrency) {
    return '1 $currency = ? $homeCurrency';
  }

  @override
  String get checkMarketRate => 'Marktkurs abrufen';

  @override
  String marketRateFound(String from, String rate, String to) {
    return 'Marktkurs: 1 $from = $rate $to';
  }

  @override
  String get useThisRate => 'Übernehmen';

  @override
  String get marketRateUnavailable =>
      'Kurs konnte nicht abgerufen werden – bitte manuell eingeben';

  @override
  String get exchangeRates => 'Wechselkurse';

  @override
  String get addRate => 'Kurs hinzufügen';

  @override
  String get newCurrency => 'Währung (3-stelliger Code)';

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

  @override
  String get errorSameCurrency =>
      'Das ist bereits die Heimatwährung der Reise — bitte eine andere wählen';

  @override
  String daysUntilDeparture(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage bis zur Abreise',
      one: '1 Tag bis zur Abreise',
    );
    return '$_temp0';
  }

  @override
  String tripLengthDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get tripFinished => 'Reise beendet';

  @override
  String dailyBudgetRemaining(String amount) {
    return 'Verbleibendes Tagesbudget: $amount/Tag';
  }

  @override
  String averageDailySpend(String amount) {
    return 'Bisheriger Tagesdurchschnitt: $amount/Tag';
  }

  @override
  String get plannedLabel => 'Geplant';

  @override
  String get actualLabel => 'Tatsächlich';

  @override
  String get remainingLabel => 'Verbleibend';

  @override
  String get viewInCurrency => 'Anzeigen in';

  @override
  String setAsHomeCurrencyPrompt(String currency) {
    return '$currency als Heimatwährung dieser Reise festlegen?';
  }

  @override
  String get viewOnly => 'Nur anzeigen';

  @override
  String get spendingByCategory => 'Ausgaben nach Kategorie';

  @override
  String get noExpensesYet => 'Noch keine Ausgaben';

  @override
  String get expenses => 'Ausgaben';

  @override
  String get markAsSpent => 'Als ausgegeben markieren';

  @override
  String get markAsSpentPrompt =>
      'Betrag anpassen, falls er vom Schätzwert abweicht, sonst unverändert lassen.';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get language => 'Sprache';

  @override
  String get systemLanguage => 'Systemsprache';

  @override
  String get myTrips => 'Meine Reisen';

  @override
  String get noTripsYet =>
      'Noch keine Reisen — tippe auf +, um deine erste zu planen';

  @override
  String get plannedTotal => 'Geplant';

  @override
  String get spentTotal => 'Ausgegeben';

  @override
  String get backupAll => 'Vollständiges Backup';

  @override
  String get restoreFromBackup => 'Aus Backup wiederherstellen';

  @override
  String importSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reisen wiederhergestellt',
      one: '1 Reise wiederhergestellt',
    );
    return '$_temp0';
  }

  @override
  String get errorImportParseFailed =>
      'Diese Datei konnte nicht als TravelSpendPlus-Backup gelesen werden';

  @override
  String get errorImportUnsupportedVersion =>
      'Dieses Backup wurde mit einer neueren App-Version erstellt — bitte zuerst aktualisieren';

  @override
  String get errorExportFailed =>
      'Export fehlgeschlagen — bitte erneut versuchen';

  @override
  String get exportTripCsv => 'Als CSV exportieren';

  @override
  String get deleteTrip => 'Reise löschen';

  @override
  String deleteTripConfirm(String name) {
    return '„$name“ und alles darin löschen? Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deleteExpense => 'Ausgabe löschen';

  @override
  String get deleteExpenseConfirm =>
      'Diese Ausgabe löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get csvHeaderDate => 'Datum';

  @override
  String get csvHeaderCategory => 'Kategorie';

  @override
  String get csvHeaderStatus => 'Status';

  @override
  String get csvHeaderDescription => 'Beschreibung';

  @override
  String get csvHeaderAmount => 'Betrag';

  @override
  String get csvHeaderCurrency => 'Währung';

  @override
  String get csvHeaderAmountInHomeCurrency => 'Betrag (Heimatwährung)';
}
