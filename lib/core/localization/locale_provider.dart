import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key the selected language is stored under. Absent (or
/// no matching entry) means "follow the device."
const localeOverridePrefsKey = 'locale_override';

/// The user's explicit in-app language choice, overriding the device
/// locale. `null` means "follow the device" — BooklyApp's
/// `localeResolutionCallback` handles that case exactly as it did before
/// this override existed.
///
/// Persisted to SharedPreferences so the choice survives an app restart.
/// The stored value must be loaded and injected via [overrideWith] before
/// `runApp` (see main.dart) so the correct language renders on the very
/// first frame instead of flashing the device locale first.
class LocaleOverride extends Notifier<Locale?> {
  final Locale? _initial;
  LocaleOverride([this._initial]);

  @override
  Locale? build() => _initial;

  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(localeOverridePrefsKey);
    } else {
      await prefs.setString(localeOverridePrefsKey, locale.languageCode);
    }
  }
}

/// Reads the persisted language choice, for use before `runApp` — see
/// main.dart. Returns null ("follow the device") if nothing was stored.
Future<Locale?> loadStoredLocaleOverride() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(localeOverridePrefsKey);
  return code == null ? null : Locale(code);
}

final localeOverrideProvider = NotifierProvider<LocaleOverride, Locale?>(
  LocaleOverride.new,
);
