import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/money.dart';
import '../domain/participant.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'formatting.dart';

class CreateTripScreen extends StatefulWidget {
  final TripRepository repository;
  final Trip? existingTrip;
  const CreateTripScreen({super.key, required this.repository, this.existingTrip});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;
  late final TextEditingController _budgetController;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _dateError;

  bool get _isEditing => widget.existingTrip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.existingTrip;
    _nameController = TextEditingController(text: trip?.name ?? '');
    _currencyController = TextEditingController(text: trip?.homeCurrency ?? 'CNY');
    _budgetController =
        TextEditingController(text: trip != null ? trip.totalBudget.major.toString() : '');
    _startDate = trip?.startDate ?? DateTime.now();
    _endDate = trip?.endDate ?? DateTime.now().add(const Duration(days: 6));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _dateError = _endDate.isBefore(_startDate) ? l10n.errorEndDateBeforeStart : null;
    });
    if (!_formKey.currentState!.validate() || _dateError != null) return;

    final currency = _currencyController.text.trim().toUpperCase();
    final budget = Money.fromMajor(double.parse(_budgetController.text), currency);

    if (_isEditing) {
      final existing = widget.existingTrip!;
      await widget.repository.updateTrip(Trip(
        id: existing.id,
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        homeCurrency: existing.homeCurrency, // currency changes go through ExchangeRateSettingsScreen only
        totalBudget: Money(minorUnits: budget.minorUnits, currencyCode: existing.homeCurrency),
        participants: existing.participants,
      ));
    } else {
      final defaultParticipant = Participant(id: const Uuid().v4(), name: 'Me');
      await widget.repository.createTrip(Trip(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        homeCurrency: currency,
        totalBudget: budget,
        participants: [defaultParticipant],
      ));
    }
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.editTrip : l10n.newTrip)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('tripNameField'),
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.tripName),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l10n.errorEnterTripName : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.startDate),
              subtitle: Text(formatDate(context, _startDate)),
              onTap: () => _pickDate(isStart: true),
            ),
            ListTile(
              title: Text(l10n.endDate),
              subtitle: Text(formatDate(context, _endDate)),
              onTap: () => _pickDate(isStart: false),
            ),
            if (_dateError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_dateError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            if (!_isEditing)
              TextFormField(
                key: const Key('tripCurrencyField'),
                controller: _currencyController,
                decoration: InputDecoration(labelText: l10n.homeCurrency),
                textCapitalization: TextCapitalization.characters,
                validator: (value) =>
                    (value?.trim().length ?? 0) == 3 ? null : l10n.errorCurrencyCode,
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('tripBudgetField'),
              controller: _budgetController,
              decoration: InputDecoration(labelText: l10n.totalBudget),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return (parsed != null && parsed > 0) ? null : l10n.errorPositiveAmount;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('saveTripButton'),
              onPressed: _save,
              child: Text(_isEditing ? l10n.saveChanges : l10n.createTrip),
            ),
          ],
        ),
      ),
    );
  }
}
