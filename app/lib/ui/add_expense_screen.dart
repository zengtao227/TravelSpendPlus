import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/civil_date.dart';
import '../domain/exchange_rate.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/money.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import '../services/expense_photo_store.dart';
import '../services/live_rate_service.dart';
import 'currency_field.dart';
import 'formatting.dart';
import 'market_rate_helper.dart';

class AddExpenseScreen extends StatefulWidget {
  final Trip trip;
  final TripRepository repository;
  final Expense? existingExpense;
  final LiveRateService? liveRateService;
  final Future<XFile?> Function() pickImage;
  AddExpenseScreen({
    super.key,
    required this.trip,
    required this.repository,
    this.existingExpense,
    this.liveRateService,
    Future<XFile?> Function()? pickImage,
  }) : pickImage = pickImage ?? (() => ImagePicker().pickImage(source: ImageSource.gallery));

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

// Never selectable via the DropdownButtonFormField's own item list under
// this value — a real category name can't collide with it (guarded in
// _promptAddCategory, which also rejects it as a typed name).
const _kAddCategorySentinel = '__add_custom_category__';

// A dedicated StatefulWidget so its TextEditingController is owned by the
// dialog's own Element and disposed in its own dispose() — when the
// controller was instead created/disposed by the caller around `await
// showDialog(...)`, disposal ran the instant Navigator.pop resolved the
// future, which is before the dialog's closing (reverse) transition
// finishes actually tearing down the TextField still holding it, throwing
// "A TextEditingController was used after being disposed."
class _AddCategoryDialog extends StatefulWidget {
  final bool Function(String trimmedName) isDuplicate;
  const _AddCategoryDialog({required this.isDuplicate});

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = l10n.errorEnterCategoryName);
      return;
    }
    if (widget.isDuplicate(trimmed)) {
      setState(() => _error = l10n.errorDuplicateCategory);
      return;
    }
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addCategory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('newCategoryNameField'),
            controller: _controller,
            decoration: InputDecoration(labelText: l10n.categoryName),
            autofocus: true,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        TextButton(
          key: const Key('confirmAddCategoryButton'),
          onPressed: _confirm,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  late final TextEditingController _amountController;
  late String _currency;
  late final TextEditingController _descriptionController;
  final _exchangeRateController = TextEditingController();
  late final TextEditingController _locationController;
  late DateTime _date;
  late DateTime _endDate;
  late bool _excludeFromBreakdown;
  late ExpenseStatus _status;
  List<ExchangeRate> _existingRates = [];
  List<String> _customCategories = [];
  String? _categoryError;
  late final LiveRateService _liveRateService;
  String? _pickedPhotoPath;
  bool _removeExistingPhoto = false;
  File? _existingPhotoFile;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    _liveRateService = widget.liveRateService ?? LiveRateService();
    final existing = widget.existingExpense;
    _category = existing?.category;
    _amountController =
        TextEditingController(text: existing != null ? existing.amount.major.toString() : '');
    _currency = existing?.amount.currencyCode ?? widget.trip.homeCurrency;
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _date = civilDate(existing?.date ?? DateTime.now());
    // Defaults to the same single day as _date — most expenses don't span
    // more than one, and the picker only needs to be touched for the ones
    // that do (e.g. a multi-night hotel stay).
    _endDate = civilDate(existing?.endDate ?? _date);
    _excludeFromBreakdown = existing?.excludeFromBreakdown ?? false;
    _status = existing?.status ?? ExpenseStatus.actual;
    _loadRates();
    _loadCategories();
    if (existing != null) _loadExistingPhoto(existing.id);
  }

  Future<void> _loadExistingPhoto(String expenseId) async {
    final has = await ExpensePhotoStore.hasPhoto(expenseId);
    if (!has) return;
    final file = await ExpensePhotoStore.photoFile(expenseId);
    if (mounted) setState(() => _existingPhotoFile = file);
  }

  Future<void> _pickPhoto() async {
    final picked = await widget.pickImage();
    if (picked == null) return;
    setState(() {
      _pickedPhotoPath = picked.path;
      _removeExistingPhoto = false;
    });
  }

  void _clearPhoto() {
    setState(() {
      _pickedPhotoPath = null;
      _removeExistingPhoto = true;
    });
  }

  bool get _showsPhoto =>
      _pickedPhotoPath != null || (_existingPhotoFile != null && !_removeExistingPhoto);

  Widget _buildPhotoPicker() {
    final showsPhoto = _showsPhoto;
    ImageProvider? imageProvider;
    if (_pickedPhotoPath != null) {
      imageProvider = FileImage(File(_pickedPhotoPath!));
    } else if (_existingPhotoFile != null && !_removeExistingPhoto) {
      imageProvider = FileImage(_existingPhotoFile!);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          key: const Key('expensePhotoPicker'),
          onTap: _pickPhoto,
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundImage: imageProvider,
            child: showsPhoto
                ? null
                : Icon(Icons.add_a_photo_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        if (showsPhoto)
          Positioned(
            right: -4,
            top: -4,
            child: GestureDetector(
              key: const Key('removeExpensePhotoButton'),
              onTap: _clearPhoto,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadRates() async {
    final rates = await widget.repository.getExchangeRates(widget.trip.id);
    if (mounted) setState(() => _existingRates = rates);
  }

  Future<void> _loadCategories() async {
    final categories = await widget.repository.getCustomCategories(widget.trip.id);
    if (mounted) setState(() => _customCategories = categories);
  }

  // Prompts for a new category name, persists it, and selects it. Declining
  // (dialog cancelled) leaves _category untouched — this dropdown is a
  // plain, fully-reactive DropdownButton (see build()), not a
  // DropdownButtonFormField, so there's no leftover "selected" state to
  // reset: the sentinel item was never treated as a real selection.
  Future<void> _promptAddCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AddCategoryDialog(
        isDuplicate: (trimmed) =>
            kExpenseCategoryKeys.contains(trimmed.toLowerCase()) ||
            _customCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase()),
      ),
    );
    if (name == null) return;
    await widget.repository.addCustomCategory(widget.trip.id, name);
    setState(() {
      _customCategories = [..._customCategories, name];
      _category = name;
      _categoryError = null;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  bool get _needsNewExchangeRate {
    if (_currency == widget.trip.homeCurrency) return false;
    return !_existingRates.any((r) => r.fromCurrency == _currency);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = civilDate(picked);
      // Keep endDate a valid single-day span by default when the start
      // date moves past it — Expense rejects endDate before date, and a
      // user picking a new start date isn't necessarily also thinking
      // about the end date they set earlier.
      if (_endDate.isBefore(_date)) _endDate = _date;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _date,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = civilDate(picked));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final formValid = _formKey.currentState!.validate();
    final categoryValid = _category != null;
    setState(() => _categoryError = categoryValid ? null : l10n.errorSelectCategory);
    if (!formValid || !categoryValid) return;

    final currency = _currency;
    final amount = Money.fromMajor(double.parse(_amountController.text), currency);
    final existing = widget.existingExpense;

    Money amountInHomeCurrency;
    if (_isEditing && currency == existing!.amount.currencyCode) {
      // Editing without changing the currency: preserve the exchange rate
      // that was locked in when this expense was first recorded, only
      // rescaling for a changed amount — never re-derive it from the trip's
      // *current* rate table. Otherwise editing an old foreign-currency
      // expense (even just its description) would silently restate its
      // home-currency total using today's rate instead of the rate that
      // actually applied at the time, contradicting this app's own
      // "exchange rate is locked at recording time" rule (the same rule
      // TripDetailScreen._markAsSpent already follows for the same reason).
      final ratio = existing.amount.minorUnits == 0
          ? 1.0
          : amount.minorUnits / existing.amount.minorUnits;
      amountInHomeCurrency = Money(
        minorUnits: (existing.amountInHomeCurrency.minorUnits * ratio).round(),
        currencyCode: existing.amountInHomeCurrency.currencyCode,
      );
    } else if (currency == widget.trip.homeCurrency) {
      amountInHomeCurrency = Money(minorUnits: amount.minorUnits, currencyCode: widget.trip.homeCurrency);
    } else {
      // Create mode, or the currency was changed during an edit: use the
      // trip's current rate for this currency (or the newly-entered one).
      final rateToUse = _existingRates.firstWhere(
        (r) => r.fromCurrency == currency,
        orElse: () => ExchangeRate(
          fromCurrency: currency,
          toCurrency: widget.trip.homeCurrency,
          // The field prompts "1 home = ? foreign" (see exchangeRatePrompt
          // below) — ExchangeRate.rate's own stored meaning is unchanged
          // ("1 fromCurrency(foreign) = rate toCurrency(home)"), so what the
          // user typed has to be inverted before it's stored.
          rate: 1 / double.parse(_exchangeRateController.text),
        ),
      );
      if (_needsNewExchangeRate) {
        await widget.repository.setExchangeRate(widget.trip.id, rateToUse);
      }
      amountInHomeCurrency = rateToUse.convert(amount);
    }
    final participant = widget.trip.participants.first;
    final expense = Expense(
      id: existing?.id ?? const Uuid().v4(),
      tripId: widget.trip.id,
      category: _category!,
      amount: amount,
      amountInHomeCurrency: amountInHomeCurrency,
      description: _descriptionController.text.trim(),
      date: _date,
      endDate: _endDate,
      location: _locationController.text.trim(),
      excludeFromBreakdown: _excludeFromBreakdown,
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
    if (_pickedPhotoPath != null) {
      await ExpensePhotoStore.saveFromPath(expense.id, _pickedPhotoPath!);
      // ExpensePhotoStore always writes to the same <expenseId>.jpg path, so
      // Flutter's global ImageCache (keyed by file path, not content) would
      // otherwise keep serving the previous photo's decoded bytes for this
      // expense's thumbnail/preview after a replace — confirmed on-device:
      // without this, swapping to a different photo silently kept showing
      // the old one.
      imageCache.evict(FileImage(await ExpensePhotoStore.photoFile(expense.id)));
    } else if (_removeExistingPhoto) {
      await ExpensePhotoStore.delete(expense.id);
      imageCache.evict(FileImage(await ExpensePhotoStore.photoFile(expense.id)));
    }
    if (mounted) Navigator.pop(context, true);
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
            Center(child: _buildPhotoPicker()),
            const SizedBox(height: 16),
            // A plain (fully-reactive) DropdownButton, not
            // DropdownButtonFormField — the latter's FormFieldState only
            // reads `initialValue` once and never re-syncs to an externally
            // changed value, which broke the moment _category was updated
            // programmatically (after adding a new category, the field kept
            // showing the "+ Add category" placeholder as if still
            // selected). Validation is done by hand in _save() instead of
            // via a Form validator, matching the same manual-error-text
            // pattern ExchangeRateSettingsScreen already uses.
            InputDecorator(
              decoration: InputDecoration(labelText: l10n.category, errorText: _categoryError),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('expenseCategoryField'),
                  value: _category,
                  isExpanded: true,
                  items: [
                    for (final key in kExpenseCategoryKeys)
                      DropdownMenuItem(
                        value: key,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(categoryIcon(key), size: 18),
                          const SizedBox(width: 8),
                          Text(categoryLabel(context, key)),
                        ]),
                      ),
                    for (final name in _customCategories)
                      DropdownMenuItem(
                        value: name,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(categoryIcon(name), size: 18),
                          const SizedBox(width: 8),
                          Text(name),
                        ]),
                      ),
                    // Defensive: an existing expense's category might not be
                    // in either list above yet (e.g. edit mode, first build,
                    // before _loadCategories's Future resolves) — without
                    // this, `value: _category` pointing at an item that
                    // isn't in `items` throws.
                    if (_category != null &&
                        !kExpenseCategoryKeys.contains(_category) &&
                        !_customCategories.contains(_category))
                      DropdownMenuItem(value: _category, child: Text(_category!)),
                    DropdownMenuItem(value: _kAddCategorySentinel, child: Text(l10n.addCategory)),
                  ],
                  onChanged: (value) {
                    if (value == _kAddCategorySentinel) {
                      _promptAddCategory();
                      return;
                    }
                    setState(() {
                      _category = value;
                      _categoryError = null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseAmountField'),
              controller: _amountController,
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                // Validate against the rounded minor-units value Money.fromMajor
                // will actually store, not the raw double — otherwise a value
                // like 0.001 passes here (0.001 > 0) but rounds to 0 cents.
                return (parsed != null && (parsed * 100).round() > 0)
                    ? null
                    : l10n.errorPositiveAmount;
              },
            ),
            const SizedBox(height: 12),
            CurrencyDropdownField(
              fieldKey: const Key('expenseCurrencyField'),
              value: _currency,
              label: l10n.currency,
              onChanged: (value) => setState(() => _currency = value),
            ),
            if (_needsNewExchangeRate) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('expenseExchangeRateField'),
                controller: _exchangeRateController,
                decoration: InputDecoration(
                  // "1 home = ? foreign" — the direction a traveler actually
                  // thinks in when exchanging cash, not "1 foreign = ? home".
                  labelText: l10n.exchangeRatePrompt(widget.trip.homeCurrency, _currency),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  return (parsed != null && parsed > 0) ? null : l10n.errorPositiveRate;
                },
              ),
              MarketRateHelper(
                // Rekeyed per currency pair so a stale fetched rate from a
                // previously-selected currency can't linger after the user
                // changes it.
                key: ValueKey('market-rate-${widget.trip.homeCurrency}-$_currency'),
                fromCurrency: widget.trip.homeCurrency,
                toCurrency: _currency,
                targetController: _exchangeRateController,
                liveRateService: _liveRateService,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseDescriptionField'),
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.description),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('expenseLocationField'),
              controller: _locationController,
              decoration:
                  InputDecoration(labelText: l10n.location, hintText: l10n.locationHint),
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('expenseDateField'),
              title: Text(l10n.date),
              subtitle: Text(formatDate(context, _date)),
              onTap: _pickDate,
            ),
            ListTile(
              key: const Key('expenseEndDateField'),
              title: Text(l10n.endDate),
              subtitle: Text(formatDate(context, _endDate)),
              onTap: _pickEndDate,
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
            CheckboxListTile(
              key: const Key('excludeFromBreakdownCheckbox'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.excludeFromChart),
              value: _excludeFromBreakdown,
              onChanged: (value) => setState(() => _excludeFromBreakdown = value ?? false),
            ),
            const SizedBox(height: 8),
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
