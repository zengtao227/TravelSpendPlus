import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's in-app language override across restarts. A stored
/// value of `null` (nothing saved) means "follow the system locale" —
/// there's no separate "system" sentinel string, absence of a key already
/// means that.
const _kLocaleOverrideKey = 'locale_override_language_code';

Future<String?> loadLocaleOverride() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kLocaleOverrideKey);
}

Future<void> saveLocaleOverride(String? languageCode) async {
  final prefs = await SharedPreferences.getInstance();
  if (languageCode == null) {
    await prefs.remove(_kLocaleOverrideKey);
  } else {
    await prefs.setString(_kLocaleOverrideKey, languageCode);
  }
}
