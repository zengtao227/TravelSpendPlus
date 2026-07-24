import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

void main() {
  runApp(const TravelSpendPlusApp());
}

class TravelSpendPlusApp extends StatelessWidget {
  const TravelSpendPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('TravelSpendPlus'))),
    );
  }
}
