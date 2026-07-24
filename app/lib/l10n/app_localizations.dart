import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('zh'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'TravelSpendPlus'**
  String get appTitle;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// No description provided for @categoryLodging.
  ///
  /// In en, this message translates to:
  /// **'Lodging'**
  String get categoryLodging;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New Trip'**
  String get newTrip;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit Trip'**
  String get editTrip;

  /// No description provided for @tripName.
  ///
  /// In en, this message translates to:
  /// **'Trip name'**
  String get tripName;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @totalBudget.
  ///
  /// In en, this message translates to:
  /// **'Total budget'**
  String get totalBudget;

  /// No description provided for @homeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Home currency'**
  String get homeCurrency;

  /// No description provided for @createTrip.
  ///
  /// In en, this message translates to:
  /// **'Create Trip'**
  String get createTrip;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @errorEnterTripName.
  ///
  /// In en, this message translates to:
  /// **'Enter a trip name'**
  String get errorEnterTripName;

  /// No description provided for @errorPositiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount'**
  String get errorPositiveAmount;

  /// No description provided for @errorEndDateBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End date must be on or after the start date'**
  String get errorEndDateBeforeStart;

  /// No description provided for @errorCurrencyCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a 3-letter currency code'**
  String get errorCurrencyCode;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get editExpense;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @statusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusPlanned;

  /// No description provided for @statusActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get statusActual;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save Expense'**
  String get saveExpense;

  /// No description provided for @errorSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get errorSelectCategory;

  /// No description provided for @errorPositiveRate.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive exchange rate'**
  String get errorPositiveRate;

  /// No description provided for @exchangeRatePrompt.
  ///
  /// In en, this message translates to:
  /// **'1 {currency} = ? {homeCurrency}'**
  String exchangeRatePrompt(String currency, String homeCurrency);

  /// No description provided for @exchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rates'**
  String get exchangeRates;

  /// No description provided for @addRate.
  ///
  /// In en, this message translates to:
  /// **'Add rate'**
  String get addRate;

  /// No description provided for @newCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency (3-letter code)'**
  String get newCurrency;

  /// No description provided for @rateValue.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateValue;

  /// No description provided for @saveRate.
  ///
  /// In en, this message translates to:
  /// **'Save rate'**
  String get saveRate;

  /// No description provided for @changeHomeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Change home currency'**
  String get changeHomeCurrency;

  /// No description provided for @newHomeCurrency.
  ///
  /// In en, this message translates to:
  /// **'New home currency'**
  String get newHomeCurrency;

  /// No description provided for @oldToNewRateLabel.
  ///
  /// In en, this message translates to:
  /// **'1 {oldCurrency} = ? {newCurrency}'**
  String oldToNewRateLabel(String oldCurrency, String newCurrency);

  /// No description provided for @confirmChangeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Confirm change'**
  String get confirmChangeCurrency;

  /// No description provided for @changeCurrencyWarning.
  ///
  /// In en, this message translates to:
  /// **'This will rescale the total budget and every expense using the rate you provide.'**
  String get changeCurrencyWarning;

  /// No description provided for @errorSameCurrency.
  ///
  /// In en, this message translates to:
  /// **'This is already the trip\'s home currency — pick a different one'**
  String get errorSameCurrency;

  /// No description provided for @daysUntilDeparture.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day until departure} other{{days} days until departure}}'**
  String daysUntilDeparture(int days);

  /// No description provided for @tripFinished.
  ///
  /// In en, this message translates to:
  /// **'Trip finished'**
  String get tripFinished;

  /// No description provided for @dailyBudgetRemaining.
  ///
  /// In en, this message translates to:
  /// **'Daily budget remaining: {amount}/day'**
  String dailyBudgetRemaining(String amount);

  /// No description provided for @plannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedLabel;

  /// No description provided for @actualLabel.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actualLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// No description provided for @viewInCurrency.
  ///
  /// In en, this message translates to:
  /// **'View in'**
  String get viewInCurrency;

  /// No description provided for @spendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get spendingByCategory;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @markAsSpent.
  ///
  /// In en, this message translates to:
  /// **'Mark as spent'**
  String get markAsSpent;

  /// No description provided for @markAsSpentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Update the amount if it differs from the estimate, or leave it as is.'**
  String get markAsSpentPrompt;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTrips;

  /// No description provided for @noTripsYet.
  ///
  /// In en, this message translates to:
  /// **'No trips yet — tap + to plan your first one'**
  String get noTripsYet;

  /// No description provided for @plannedTotal.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedTotal;

  /// No description provided for @spentTotal.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentTotal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
