import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../domain/budget_calculator.dart';
import '../domain/trip.dart';
import '../persistence/trip_repository.dart';
import 'create_trip_screen.dart';
import 'formatting.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  final TripRepository repository;
  const TripListScreen({super.key, required this.repository});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  late Future<List<Trip>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getAllTrips();
  }

  void _refresh() => setState(() {
        _future = widget.repository.getAllTrips();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myTrips)),
      body: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noTripsYet, textAlign: TextAlign.center),
            ));
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
                  Text(trip.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${formatDate(context, trip.startDate)} - ${formatDate(context, trip.endDate)}'),
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
