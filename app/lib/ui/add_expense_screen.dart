import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/exchange_rate.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/money.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'formatting.dart';

class AddExpenseScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  final Expense? existingExpense;
  const AddExpenseScreen({
    super.key,
    required this.trip,
    required this.repository,
    this.existingExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _descriptionController;
  final _exchangeRateController = TextEditingController();
  late DateTime _date;
  late ExpenseStatus _status;
  List<ExchangeRate> _existingRates = [];

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingExpense;
    _category = existing?.category;
    _amountController =
        TextEditingController(text: existing != null ? existing.amount.major.toString() : '');
    _currencyController =
        TextEditingController(text: existing?.amount.currencyCode ?? widget.trip.homeCurrency);
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _date = existing?.date ?? DateTime.now();
    _status = existing?.status ?? ExpenseStatus.actual;
    _currencyController.addListener(() => setState(() {}));
    _loadRates();
  }

  Future<void> _loadRates() async {
    final rates = await widget.repository.getExchangeRates(widget.trip.id);
    if (mounted) setState(() => _existingRates = rates);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _descriptionController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  bool get _needsNewExchangeRate {
    final currency = _currencyController.text.trim().toUpperCase();
    if (currency == widget.trip.homeCurrency || currency.length != 3) return false;
    return !_existingRates.any((r) => r.fromCurrency == currency);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currency = _currencyController.text.trim().toUpperCase();
    final amount = Money.fromMajor(double.parse(_amountController.text), currency);

    ExchangeRate? rateToUse;
    if (currency != widget.trip.homeCurrency) {
      rateToUse = _existingRates.firstWhere(
        (r) => r.fromCurrency == currency,
        orElse: () => ExchangeRate(
          fromCurrency: currency,
          toCurrency: widget.trip.homeCurrency,
          rate: double.parse(_exchangeRateController.text),
        ),
      );
      if (_needsNewExchangeRate) {
        await widget.repository.setExchangeRate(widget.trip.id, rateToUse);
      }
    }
    final amountInHomeCurrency = currency == widget.trip.homeCurrency
        ? Money(minorUnits: amount.minorUnits, currencyCode: widget.trip.homeCurrency)
        : rateToUse!.convert(amount);

    final existing = widget.existingExpense;
    final participant = widget.trip.participants.first;
    final expense = Expense(
      id: existing?.id ?? const Uuid().v4(),
      tripId: widget.trip.id,
      category: _category!,
      amount: amount,
      amountInHomeCurrency: amountInHomeCurrency,
      description: _descriptionController.text.trim(),
      date: _date,
      status: _status,
      includeInSplit: true,
      paidBy: existing?.paidBy ?? participant,
      paidFor: existing?.paidFor ?? [participant],
    );
    if (_isEditing) {
      await widget.repository.updateExpense(expense);
    } else {
      await widget.repository.addExpense(expense);
    }
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.editExpense : l10n.addExpense)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              key: const Key('expenseCategoryField'),
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.category),
              items: [
                for (final key in kExpenseCategoryKeys)
                  DropdownMenuItem(value: key, child: Text(categoryLabel(context, key))),
              ],
              onChanged: (value) => setState(() => _category = value),
              validator: (value) => value == null ? l10n.errorSelectCategory : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseAmountField'),
              controller: _amountController,
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return (parsed != null && parsed > 0) ? null : l10n.errorPositiveAmount;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseCurrencyField'),
              controller: _currencyController,
              decoration: InputDecoration(labelText: l10n.currency),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_needsNewExchangeRate) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('expenseExchangeRateField'),
                controller: _exchangeRateController,
                decoration: InputDecoration(
                  labelText: l10n.exchangeRatePrompt(
                    _currencyController.text.trim().toUpperCase(),
                    widget.trip.homeCurrency,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  return (parsed != null && parsed > 0) ? null : l10n.errorPositiveRate;
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseDescriptionField'),
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.description),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.date),
              subtitle: Text(formatDate(context, _date)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ExpenseStatus>(
              segments: [
                ButtonSegment(value: ExpenseStatus.planned, label: Text(l10n.statusPlanned)),
                ButtonSegment(value: ExpenseStatus.actual, label: Text(l10n.statusActual)),
              ],
              selected: {_status},
              onSelectionChanged: (selection) => setState(() => _status = selection.first),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('saveExpenseButton'),
              onPressed: _save,
              child: Text(_isEditing ? l10n.saveChanges : l10n.saveExpense),
            ),
          ],
        ),
      ),
    );
  }
}
