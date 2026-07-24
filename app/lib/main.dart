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
  // Test-only override: leave null in production so the app follows the
  // device's own system locale. Exists because integration tests need to
  // assert against a specific language's strings regardless of whatever
  // locale the test device/emulator happens to be set to (previously the
  // golden-path test only passed by accident, because the dev emulator's
  // system locale was already zh-CN).
  final Locale? locale;
  const TravelSpendPlusApp({super.key, required this.repository, this.locale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: TripListScreen(repository: repository),
    );
  }
}
