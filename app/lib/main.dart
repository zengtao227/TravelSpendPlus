import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import 'persistence/database.dart';
import 'persistence/locale_preference.dart' as locale_preference;
import 'persistence/trip_repository.dart';
import 'ui/theme.dart';
import 'ui/trip_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.openOnDevice();
  runApp(TravelSpendPlusApp(repository: TripRepository(db)));
}

class TravelSpendPlusApp extends StatefulWidget {
  final TripRepository repository;
  // Test-only override: leave null in production so the app follows the
  // device's own system locale (or the user's saved in-app choice, once
  // loaded). Exists because integration tests need to assert against a
  // specific language's strings regardless of whatever locale the test
  // device/emulator happens to be set to (previously the golden-path test
  // only passed by accident, because the dev emulator's system locale was
  // already zh-CN). When set, the persisted preference is never loaded and
  // the in-app language switcher has nothing to change.
  final Locale? locale;
  final Future<String?> Function() loadLocaleOverride;
  final Future<void> Function(String?) saveLocaleOverride;

  const TravelSpendPlusApp({
    super.key,
    required this.repository,
    this.locale,
    this.loadLocaleOverride = locale_preference.loadLocaleOverride,
    this.saveLocaleOverride = locale_preference.saveLocaleOverride,
  });

  @override
  State<TravelSpendPlusApp> createState() => _TravelSpendPlusAppState();
}

class _TravelSpendPlusAppState extends State<TravelSpendPlusApp> {
  Locale? _localeOverride;

  @override
  void initState() {
    super.initState();
    if (widget.locale == null) {
      widget.loadLocaleOverride().then((code) {
        if (!mounted || code == null) return;
        setState(() => _localeOverride = Locale(code));
      });
    }
  }

  Future<void> _setLocale(Locale? locale) async {
    await widget.saveLocaleOverride(locale?.languageCode);
    setState(() => _localeOverride = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.locale ?? _localeOverride,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: TripListScreen(
        repository: widget.repository,
        currentLocale: widget.locale ?? _localeOverride,
        onLocaleChanged: widget.locale == null ? _setLocale : null,
      ),
    );
  }
}
