import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import 'persistence/database.dart';
import 'persistence/trip_repository.dart';
import 'ui/theme.dart';
import 'ui/trip_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.openOnDevice();
  runApp(TravelSpendPlusApp(repository: TripRepository(db)));
}

class TravelSpendPlusApp extends StatelessWidget {
  final TripRepository repository;
  const TravelSpendPlusApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: TripListScreen(repository: repository),
    );
  }
}
