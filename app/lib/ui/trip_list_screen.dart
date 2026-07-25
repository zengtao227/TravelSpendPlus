import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/backup.dart';
import '../domain/budget_calculator.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import '../services/trip_photo_store.dart';
import '../version.dart';
import 'create_trip_screen.dart';
import 'file_io.dart' as file_io;
import 'formatting.dart';
import 'theme.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  final TripRepository repository;
  final Future<String> Function(String filename, String content) writeTempFile;
  final Future<void> Function(String path, {String? subject}) shareFile;
  final Future<String?> Function() pickJsonFile;
  // The language button only appears when this is non-null — main.dart
  // leaves it null while a test-pinned locale is active (see
  // TravelSpendPlusApp.locale), since there's nothing for the switcher to
  // change in that case.
  final Locale? currentLocale;
  final Future<void> Function(Locale?)? onLocaleChanged;

  const TripListScreen({
    super.key,
    required this.repository,
    this.writeTempFile = file_io.writeTempFile,
    this.shareFile = file_io.shareFile,
    this.pickJsonFile = file_io.pickJsonFile,
    this.currentLocale,
    this.onLocaleChanged,
  });

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _LanguageChoice {
  final Locale? locale; // null = system default
  const _LanguageChoice(this.locale);
}

class _TripListScreenState extends State<TripListScreen> {
  late Future<List<Trip>> _future;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getAllTrips();
  }

  void _refresh() => setState(() {
        _future = widget.repository.getAllTrips();
      });

  Future<void> _exportAll() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final json = await widget.repository.exportAllTripsToJson();
      final content = const JsonEncoder.withIndent('  ').convert(json);
      final path = await widget.writeTempFile(
        'travelspendplus_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        content,
      );
      await widget.shareFile(path, subject: l10n.backupAll);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorExportFailed)));
    }
  }

  // Each language's own name, in its own script — the standard convention
  // for language pickers (so a user who can't read the current UI language
  // can still recognize their own), not translated per current locale.
  static const _languageNames = {'en': 'English', 'zh': '中文', 'de': 'Deutsch'};

  Future<void> _pickLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    // Wrapped in _LanguageChoice (rather than returning Locale? directly)
    // so a real "System default" pick (choice.locale == null) can be told
    // apart from the dialog being dismissed without any choice (choice ==
    // null) — otherwise dismissing the dialog would silently reset the
    // locale to system default.
    final choice = await showDialog<_LanguageChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          SimpleDialogOption(
            key: const Key('languageOptionSystem'),
            onPressed: () => Navigator.pop(context, const _LanguageChoice(null)),
            child: Text(l10n.systemLanguage),
          ),
          for (final locale in AppLocalizations.supportedLocales)
            SimpleDialogOption(
              key: Key('languageOption_${locale.languageCode}'),
              onPressed: () => Navigator.pop(context, _LanguageChoice(locale)),
              child: Text(_languageNames[locale.languageCode] ?? locale.languageCode),
            ),
        ],
      ),
    );
    if (choice == null) return; // dismissed without picking anything
    await widget.onLocaleChanged?.call(choice.locale);
  }

  Future<void> _importAll() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _importError = null);
    final content = await widget.pickJsonFile(); // returns file content, not a path — see file_io.dart
    if (content == null) return; // user cancelled
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final count = await widget.repository.importAllTripsFromJson(json);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importSuccess(count))));
      _refresh();
    } on UnsupportedBackupVersionException {
      if (!mounted) return;
      setState(() => _importError = l10n.errorImportUnsupportedVersion);
    } catch (_) {
      if (!mounted) return;
      setState(() => _importError = l10n.errorImportParseFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myTrips),
        actions: [
          if (widget.onLocaleChanged != null)
            IconButton(
              key: const Key('languageButton'),
              icon: const Icon(Icons.language),
              tooltip: l10n.language,
              onPressed: _pickLanguage,
            ),
          IconButton(
            key: const Key('backupAllButton'),
            icon: const Icon(Icons.backup),
            tooltip: l10n.backupAll,
            onPressed: _exportAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Trip>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final trips = snapshot.data ?? [];
                if (trips.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.noTripsYet, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            key: const Key('restoreFromBackupButton'),
                            icon: const Icon(Icons.restore),
                            label: Text(l10n.restoreFromBackup),
                            onPressed: _importAll,
                          ),
                          if (_importError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_importError!,
                                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    return _TripCard(
                      trip: trips[index],
                      repository: widget.repository,
                      onReturned: _refresh,
                    );
                  },
                );
              },
            ),
          ),
          // Lets a screenshot settle "which build is this" arguments
          // instantly, instead of guessing from behavior.
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'v$kAppVersion',
              key: const Key('appVersionLabel'),
              style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => CreateTripScreen(repository: widget.repository)));
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// A small round avatar showing the trip's stored photo, if any — renders
// nothing (zero-size) for a trip with no photo, so trips without one don't
// show an empty placeholder circle cluttering the list.
class _TripPhotoThumbnail extends StatelessWidget {
  final String tripId;
  const _TripPhotoThumbnail({required this.tripId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: TripPhotoStore.hasPhoto(tripId),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return FutureBuilder<File>(
          future: TripPhotoStore.photoFile(tripId),
          builder: (context, fileSnapshot) {
            if (!fileSnapshot.hasData) return const SizedBox.shrink();
            return CircleAvatar(radius: 24, backgroundImage: FileImage(fileSnapshot.data!));
          },
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final TripRepository repository;
  final VoidCallback onReturned;
  const _TripCard({required this.trip, required this.repository, required this.onReturned});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: repository.getExpenses(trip.id),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        final summary = BudgetCalculator.summarize(trip: trip, expenses: expenses);
        // Total *committed* money (already spent + planned/estimated) is
        // what the progress bar should reflect against the budget — that's
        // not the bug. The bug was showing this combined figure under the
        // single "Spent" label, which misrepresents planned money as
        // already spent. Below, actual and planned are shown as two
        // distinct, separately-labeled figures (matching the pattern
        // TripDetailScreen's budget-summary card already uses).
        final committed = summary.actualTotal + summary.plannedTotal;
        final progress = trip.totalBudget.minorUnits == 0
            ? 0.0
            : committed.minorUnits / trip.totalBudget.minorUnits;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripDetailScreen(tripId: trip.id, repository: repository),
                ),
              );
              onReturned();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TripPhotoThumbnail(tripId: trip.id),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${formatDate(context, trip.startDate)} - ${formatDate(context, trip.endDate)} '
                              '(${l10n.tripLengthDays(trip.totalDays)})',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${l10n.spentTotal} ${formatMoney(summary.actualTotal)}'),
                      // No planned expenses at all for this trip — showing
                      // "Planned EUR 0.00" here would just be noise, not a
                      // real zero the user set.
                      if (summary.plannedTotal.minorUnits != 0)
                        Text('${l10n.plannedTotal} ${formatMoney(summary.plannedTotal)}'),
                      Text(formatMoney(trip.totalBudget)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
