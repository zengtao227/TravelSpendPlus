import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/civil_date.dart';
import '../domain/money.dart';
import '../domain/participant.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import '../services/trip_photo_store.dart';
import 'currency_field.dart';
import 'formatting.dart';

class CreateTripScreen extends StatefulWidget {
  final TripRepository repository;
  final Trip? existingTrip;
  // Injectable so widget tests can supply a fake picker instead of hitting
  // the real platform channel (which has no implementation in the test
  // harness) — same pattern as AddExpenseScreen's liveRateService and
  // TripDetailScreen's writeTempFile/shareFile.
  final Future<XFile?> Function() pickImage;
  CreateTripScreen({
    super.key,
    required this.repository,
    this.existingTrip,
    Future<XFile?> Function()? pickImage,
  }) : pickImage = pickImage ?? (() => ImagePicker().pickImage(source: ImageSource.gallery));

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _currency;
  late final TextEditingController _budgetController;
  late bool _hasBudget;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _dateError;
  // A freshly picked photo not yet written to TripPhotoStore (that happens
  // in _save(), once we know the trip's final id) — null means "unchanged
  // from whatever's already stored", not "no photo".
  String? _pickedPhotoPath;
  bool _removeExistingPhoto = false;
  File? _existingPhotoFile;

  bool get _isEditing => widget.existingTrip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.existingTrip;
    _nameController = TextEditingController(text: trip?.name ?? '');
    _currency = trip?.homeCurrency ?? 'EUR';
    // Off by default for a new trip — budget tracking is opt-in, not
    // something you have to notice and skip. An existing trip's own state
    // (0 minor units means "no budget" throughout this app) decides it.
    _hasBudget = trip != null && trip.totalBudget.minorUnits != 0;
    _budgetController =
        TextEditingController(text: trip != null ? trip.totalBudget.major.toString() : '');
    _startDate = civilDate(trip?.startDate ?? DateTime.now());
    _endDate = civilDate(trip?.endDate ?? DateTime.now().add(const Duration(days: 6)));
    if (trip != null) _loadExistingPhoto(trip.id);
  }

  Future<void> _loadExistingPhoto(String tripId) async {
    final has = await TripPhotoStore.hasPhoto(tripId);
    if (!has) return;
    final file = await TripPhotoStore.photoFile(tripId);
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

  @override
  void dispose() {
    _nameController.dispose();
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
    setState(() => isStart ? _startDate = civilDate(picked) : _endDate = civilDate(picked));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _dateError = _endDate.isBefore(_startDate) ? l10n.errorEndDateBeforeStart : null;
    });
    if (!_formKey.currentState!.validate() || _dateError != null) return;

    final currency = _currency;
    final budgetText = _budgetController.text.trim();
    final budget = _hasBudget
        ? Money.fromMajor(budgetText.isEmpty ? 0 : double.parse(budgetText), currency)
        : Money(minorUnits: 0, currencyCode: currency);

    final String tripId;
    if (_isEditing) {
      final existing = widget.existingTrip!;
      tripId = existing.id;
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
      tripId = const Uuid().v4();
      final defaultParticipant = Participant(id: const Uuid().v4(), name: 'Me');
      await widget.repository.createTrip(Trip(
        id: tripId,
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        homeCurrency: currency,
        totalBudget: budget,
        participants: [defaultParticipant],
      ));
    }
    if (_pickedPhotoPath != null) {
      await TripPhotoStore.saveFromPath(tripId, _pickedPhotoPath!);
    } else if (_removeExistingPhoto) {
      await TripPhotoStore.delete(tripId);
    }
    if (mounted) Navigator.pop(context, true);
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
            Center(child: _buildPhotoPicker()),
            const SizedBox(height: 16),
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
              CurrencyDropdownField(
                fieldKey: const Key('tripCurrencyField'),
                value: _currency,
                label: l10n.homeCurrency,
                onChanged: (value) => setState(() => _currency = value),
              ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('trackBudgetSwitch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trackBudget),
              value: _hasBudget,
              onChanged: (value) => setState(() => _hasBudget = value),
            ),
            if (_hasBudget)
              TextFormField(
                key: const Key('tripBudgetField'),
                controller: _budgetController,
                decoration: InputDecoration(labelText: l10n.totalBudget),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null; // optional: blank means no budget (0)
                  final parsed = double.tryParse(trimmed);
                  return (parsed != null && parsed >= 0) ? null : l10n.errorPositiveAmount;
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

  // Whether the avatar should currently render a photo — a freshly picked
  // one always wins, otherwise an existing stored one unless the user just
  // tapped to remove it.
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
          key: const Key('tripPhotoPicker'),
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
              key: const Key('removeTripPhotoButton'),
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
}
