// app/lib/ui/exchange_rate_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/currency_list.dart';
import '../domain/exchange_rate.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'currency_field.dart';

class ExchangeRateSettingsScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  const ExchangeRateSettingsScreen({super.key, required this.trip, required this.repository});

  @override
  State<ExchangeRateSettingsScreen> createState() => _ExchangeRateSettingsScreenState();
}

class _ExchangeRateSettingsScreenState extends State<ExchangeRateSettingsScreen> {
  late Future<List<ExchangeRate>> _ratesFuture;
  late String _newRateCurrency;
  final _newRateValue = TextEditingController();
  bool _showChangeCurrencyForm = false;
  late String _newHomeCurrency;
  final _oldToNewRate = TextEditingController();
  String? _changeCurrencyError;
  String? _addRateError;

  // A currency dropdown always needs a starting value; default to the first
  // curated currency that isn't already the trip's home currency (picking
  // the home currency itself would be a nonsensical default here).
  static String _defaultOtherCurrency(String homeCurrency) =>
      kAllCurrencyCodesOrdered.firstWhere((c) => c != homeCurrency, orElse: () => homeCurrency);

  @override
  void initState() {
    super.initState();
    _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
    _newRateCurrency = _defaultOtherCurrency(widget.trip.homeCurrency);
    _newHomeCurrency = _defaultOtherCurrency(widget.trip.homeCurrency);
  }

  @override
  void dispose() {
    _newRateValue.dispose();
    _oldToNewRate.dispose();
    super.dispose();
  }

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

  Future<void> _confirmChangeCurrency() async {
    final l10n = AppLocalizations.of(context)!;
    final newCurrency = _newHomeCurrency;
    final rate = double.tryParse(_oldToNewRate.text);
    if (rate == null || rate <= 0) {
      setState(() => _changeCurrencyError = l10n.errorPositiveRate);
      return;
    }
    if (newCurrency == widget.trip.homeCurrency) {
      // Catch this here with a plain, visible error rather than only
      // relying on TripRepository.changeHomeCurrency's ArgumentError —
      // that guard exists too, but a thrown exception with no on-screen
      // message would look like the button silently did nothing.
      setState(() => _changeCurrencyError = l10n.errorSameCurrency);
      return;
    }
    setState(() => _changeCurrencyError = null);
    await widget.repository.changeHomeCurrency(
      tripId: widget.trip.id,
      newCurrency: newCurrency,
      oldToNewRate: rate,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exchangeRates)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<ExchangeRate>>(
            future: _ratesFuture,
            builder: (context, snapshot) {
              final rates = snapshot.data ?? [];
              return Column(
                children: [
                  for (final rate in rates)
                    ListTile(
                      // Displayed as "1 home = ? foreign", matching the
                      // input direction — rate.rate itself still means
                      // "1 fromCurrency(foreign) = rate toCurrency(home)".
                      title: Text('1 ${rate.toCurrency} = ${1 / rate.rate} ${rate.fromCurrency}'),
                    ),
                ],
              );
            },
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
            TextField(
              key: const Key('oldToNewRateField'),
              controller: _oldToNewRate,
              decoration: InputDecoration(
                labelText: l10n.oldToNewRateLabel(widget.trip.homeCurrency, _newHomeCurrency),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_changeCurrencyError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_changeCurrencyError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ElevatedButton(
              key: const Key('confirmChangeCurrencyButton'),
              onPressed: _confirmChangeCurrency,
              child: Text(l10n.confirmChangeCurrency),
            ),
          ],
        ],
      ),
    );
  }
}
