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

  @override
  String get addExpense => 'Add Expense';

  @override
  String get editExpense => 'Edit Expense';

  @override
  String get category => 'Category';

  @override
  String get amount => 'Amount';

  @override
  String get currency => 'Currency';

  @override
  String get description => 'Description';

  @override
  String get date => 'Date';

  @override
  String get statusPlanned => 'Planned';

  @override
  String get statusActual => 'Actual';

  @override
  String get saveExpense => 'Save Expense';

  @override
  String get errorSelectCategory => 'Select a category';

  @override
  String get errorPositiveRate => 'Enter a positive exchange rate';

  @override
  String exchangeRatePrompt(String currency, String homeCurrency) {
    return '1 $currency = ? $homeCurrency';
  }

  @override
  String get exchangeRates => 'Exchange Rates';

  @override
  String get addRate => 'Add rate';

  @override
  String get newCurrency => 'Currency (3-letter code)';

  @override
  String get rateValue => 'Rate';

  @override
  String get saveRate => 'Save rate';

  @override
  String get changeHomeCurrency => 'Change home currency';

  @override
  String get newHomeCurrency => 'New home currency';

  @override
  String oldToNewRateLabel(String oldCurrency, String newCurrency) {
    return '1 $oldCurrency = ? $newCurrency';
  }

  @override
  String get confirmChangeCurrency => 'Confirm change';

  @override
  String get changeCurrencyWarning =>
      'This will rescale the total budget and every expense using the rate you provide.';

  @override
  String daysUntilDeparture(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days until departure',
      one: '1 day until departure',
    );
    return '$_temp0';
  }

  @override
  String get tripFinished => 'Trip finished';

  @override
  String dailyBudgetRemaining(String amount) {
    return 'Daily budget remaining: $amount/day';
  }

  @override
  String get plannedLabel => 'Planned';

  @override
  String get actualLabel => 'Actual';

  @override
  String get remainingLabel => 'Remaining';

  @override
  String get viewInCurrency => 'View in';

  @override
  String get spendingByCategory => 'Spending by category';

  @override
  String get noExpensesYet => 'No expenses yet';

  @override
  String get expenses => 'Expenses';

  @override
  String get markAsSpent => 'Mark as spent';

  @override
  String get markAsSpentPrompt =>
      'Update the amount if it differs from the estimate, or leave it as is.';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get myTrips => 'My Trips';

  @override
  String get noTripsYet => 'No trips yet — tap + to plan your first one';

  @override
  String get plannedTotal => 'Planned';

  @override
  String get spentTotal => 'Spent';
}
