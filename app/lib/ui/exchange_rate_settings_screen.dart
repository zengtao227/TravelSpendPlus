// app/lib/ui/exchange_rate_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/exchange_rate.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';

class ExchangeRateSettingsScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  const ExchangeRateSettingsScreen({super.key, required this.trip, required this.repository});

  @override
  State<ExchangeRateSettingsScreen> createState() => _ExchangeRateSettingsScreenState();
}

class _ExchangeRateSettingsScreenState extends State<ExchangeRateSettingsScreen> {
  late Future<List<ExchangeRate>> _ratesFuture;
  final _newRateCurrency = TextEditingController();
  final _newRateValue = TextEditingController();
  bool _showChangeCurrencyForm = false;
  final _newHomeCurrency = TextEditingController();
  final _oldToNewRate = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
  }

  void _refresh() => setState(() {
        _ratesFuture = widget.repository.getExchangeRates(widget.trip.id);
      });

  Future<void> _saveRate() async {
    final currency = _newRateCurrency.text.trim().toUpperCase();
    final rate = double.tryParse(_newRateValue.text);
    if (currency.length != 3 || rate == null || rate <= 0) return;
    await widget.repository.setExchangeRate(
      widget.trip.id,
      ExchangeRate(fromCurrency: currency, toCurrency: widget.trip.homeCurrency, rate: rate),
    );
    _newRateCurrency.clear();
    _newRateValue.clear();
    _refresh();
  }

  Future<void> _confirmChangeCurrency() async {
    final newCurrency = _newHomeCurrency.text.trim().toUpperCase();
    final rate = double.tryParse(_oldToNewRate.text);
    if (newCurrency.length != 3 || rate == null || rate <= 0) return;
    await widget.repository.changeHomeCurrency(
      tripId: widget.trip.id,
      newCurrency: newCurrency,
      oldToNewRate: rate,
    );
    if (context.mounted) Navigator.pop(context, true);
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
                      title: Text('1 ${rate.fromCurrency} = ${rate.rate} ${rate.toCurrency}'),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          Text(l10n.addRate, style: Theme.of(context).textTheme.titleSmall),
          TextField(
            key: const Key('newRateCurrencyField'),
            controller: _newRateCurrency,
            decoration: InputDecoration(labelText: l10n.newCurrency),
            textCapitalization: TextCapitalization.characters,
          ),
          TextField(
            key: const Key('newRateValueField'),
            controller: _newRateValue,
            decoration: InputDecoration(labelText: l10n.rateValue),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            TextField(
              key: const Key('newHomeCurrencyField'),
              controller: _newHomeCurrency,
              decoration: InputDecoration(labelText: l10n.newHomeCurrency),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              key: const Key('oldToNewRateField'),
              controller: _oldToNewRate,
              decoration: InputDecoration(
                labelText: l10n.oldToNewRateLabel(
                  widget.trip.homeCurrency,
                  _newHomeCurrency.text.trim().isEmpty ? '?' : _newHomeCurrency.text.trim(),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
