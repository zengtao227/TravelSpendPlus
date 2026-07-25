// app/lib/ui/exchange_rate_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/currency_list.dart';
import '../domain/exchange_rate.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import '../services/live_rate_service.dart';
import 'currency_field.dart';
import 'market_rate_helper.dart';

class ExchangeRateSettingsScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  final LiveRateService? liveRateService;
  const ExchangeRateSettingsScreen({
    super.key,
    required this.trip,
    required this.repository,
    this.liveRateService,
  });

  @override
  State<ExchangeRateSettingsScreen> createState() => _ExchangeRateSettingsScreenState();
}

class _ExchangeRateSettingsScreenState extends State<ExchangeRateSettingsScreen> {
  late Future<List<ExchangeRate>> _ratesFuture;
  late String _newRateCurrency;
  final _newRateValue = TextEditingController();
  bool _showChangeCurrencyForm = false;
  late String _newHomeCurrency;
  final Map<String, TextEditingController> _directRateControllers = {};
  String? _changeCurrencyError;
  String? _addRateError;
  late final LiveRateService _liveRateService;

  // A currency dropdown always needs a starting value; default to the first
  // curated currency that isn't already the trip's home currency (picking
  // the home currency itself would be a nonsensical default here).
  static String _defaultOtherCurrency(String homeCurrency) =>
      kAllCurrencyCodesOrdered.firstWhere((c) => c != homeCurrency, orElse: () => homeCurrency);

  @override
  void initState() {
    super.initState();
    _liveRateService = widget.liveRateService ?? LiveRateService();
    _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
    _newRateCurrency = _defaultOtherCurrency(widget.trip.homeCurrency);
    _newHomeCurrency = _defaultOtherCurrency(widget.trip.homeCurrency);
  }

  @override
  void dispose() {
    _newRateValue.dispose();
    for (final controller in _directRateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _directRateControllerFor(String currency) =>
      _directRateControllers.putIfAbsent(currency, () => TextEditingController());

  void _refresh() => setState(() {
        _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
      });

  Future<void> _saveRate() async {
    final l10n = AppLocalizations.of(context)!;
    final currency = _newRateCurrency;
    final rate = double.tryParse(_newRateValue.text);
    // The dropdown can't produce an invalid currency code, so the only
    // remaining rejection path is the rate — but it must still set a
    // visible error, not look like the button silently did nothing.
    if (rate == null || rate <= 0) {
      setState(() => _addRateError = l10n.errorPositiveRate);
      return;
    }
    setState(() => _addRateError = null);
    await widget.repository.setExchangeRate(
      widget.trip.id,
      // The field prompts "1 home = ? foreign" — ExchangeRate.rate's stored
      // meaning stays "1 fromCurrency(foreign) = rate toCurrency(home)", so
      // the typed value is inverted before it's stored.
      ExchangeRate(fromCurrency: currency, toCurrency: widget.trip.homeCurrency, rate: 1 / rate),
    );
    _newRateValue.clear();
    setState(() => _newRateCurrency = _defaultOtherCurrency(widget.trip.homeCurrency));
    _refresh();
  }

  // Also shown as a SnackBar, not just the inline text near the confirm
  // button — with one direct-rate field per currency in use, that button
  // (and the error beside it) can end up scrolled out of view, and an
  // inline-only error there could look like the button silently did
  // nothing at all.
  void _showChangeCurrencyError(String message) {
    setState(() => _changeCurrencyError = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmChangeCurrency(Set<String> requiredCurrencies) async {
    final l10n = AppLocalizations.of(context)!;
    final newCurrency = _newHomeCurrency;
    if (newCurrency == widget.trip.homeCurrency) {
      // Catch this here with a plain, visible error rather than only
      // relying on TripRepository.changeHomeCurrency's ArgumentError —
      // that guard exists too, but a thrown exception with no on-screen
      // message would look like the button silently did nothing.
      _showChangeCurrencyError(l10n.errorSameCurrency);
      return;
    }
    // One direct "1 currency = ? newCurrency" rate per currency actually in
    // use in the trip — never derived by chaining through another currency,
    // so e.g. a JPY expense gets its own real JPY->newCurrency rate instead
    // of being funneled through the old home currency's rate.
    final rates = <String, double>{};
    for (final currency in requiredCurrencies) {
      final rate = double.tryParse(_directRateControllerFor(currency).text);
      if (rate == null || rate <= 0) {
        _showChangeCurrencyError(l10n.errorPositiveRate);
        return;
      }
      rates[currency] = rate;
    }
    setState(() => _changeCurrencyError = null);
    await widget.repository.changeHomeCurrency(
      tripId: widget.trip.id,
      newCurrency: newCurrency,
      directRatesToNewCurrency: rates,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exchangeRates)),
      body: FutureBuilder<List<ExchangeRate>>(
        future: _ratesFuture,
        builder: (context, snapshot) {
          final rates = snapshot.data ?? [];
          // Every currency actually in use in the trip other than the
          // chosen new home currency: the trip's current home currency,
          // plus every currency that already has a rate row (every
          // non-home-currency expense always has one — see
          // AddExpenseScreen). Each needs its own direct rate to the new
          // home currency when changing currencies.
          final requiredCurrencies = <String>{
            widget.trip.homeCurrency,
            ...rates.map((r) => r.fromCurrency),
          }..remove(_newHomeCurrency);

          return ListView(
            // Extra bottom padding: a trip using several currencies can grow
            // one direct-rate field per currency, pushing the confirm
            // button below a short viewport.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            children: [
              for (final rate in rates)
                ListTile(
                  // Displayed as "1 home = ? foreign", matching the input
                  // direction — rate.rate itself still means "1
                  // fromCurrency(foreign) = rate toCurrency(home)".
                  title: Text('1 ${rate.toCurrency} = ${1 / rate.rate} ${rate.fromCurrency}'),
                ),
              const Divider(),
              Text(l10n.addRate, style: Theme.of(context).textTheme.titleSmall),
              CurrencyDropdownField(
                fieldKey: const Key('newRateCurrencyField'),
                value: _newRateCurrency,
                label: l10n.newCurrency,
                onChanged: (value) => setState(() => _newRateCurrency = value),
              ),
              TextField(
                key: const Key('newRateValueField'),
                controller: _newRateValue,
                decoration: InputDecoration(
                  labelText: l10n.exchangeRatePrompt(widget.trip.homeCurrency, _newRateCurrency),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              MarketRateHelper(
                key: ValueKey('market-rate-${widget.trip.homeCurrency}-$_newRateCurrency'),
                fromCurrency: widget.trip.homeCurrency,
                toCurrency: _newRateCurrency,
                targetController: _newRateValue,
                liveRateService: _liveRateService,
              ),
              if (_addRateError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_addRateError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ElevatedButton(
                key: const Key('saveRateButton'),
                onPressed: _saveRate,
                child: Text(l10n.saveRate),
              ),
              const Divider(height: 32),
              if (!_showChangeCurrencyForm)
                OutlinedButton(
                  key: const Key('changeCurrencyButton'),
                  onPressed: () => setState(() => _showChangeCurrencyForm = true),
                  child: Text(l10n.changeHomeCurrency),
                )
              else ...[
                Text(l10n.changeCurrencyWarning,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                CurrencyDropdownField(
                  fieldKey: const Key('newHomeCurrencyField'),
                  value: _newHomeCurrency,
                  label: l10n.newHomeCurrency,
                  onChanged: (value) => setState(() => _newHomeCurrency = value),
                ),
                for (final currency in requiredCurrencies)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: Key('directRateField_$currency'),
                          controller: _directRateControllerFor(currency),
                          decoration: InputDecoration(
                            labelText: l10n.oldToNewRateLabel(currency, _newHomeCurrency),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        MarketRateHelper(
                          key: ValueKey('market-rate-$currency-$_newHomeCurrency'),
                          fromCurrency: currency,
                          toCurrency: _newHomeCurrency,
                          targetController: _directRateControllerFor(currency),
                          liveRateService: _liveRateService,
                        ),
                      ],
                    ),
                  ),
                if (_changeCurrencyError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_changeCurrencyError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ElevatedButton(
                  key: const Key('confirmChangeCurrencyButton'),
                  onPressed: () => _confirmChangeCurrency(requiredCurrencies),
                  child: Text(l10n.confirmChangeCurrency),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
