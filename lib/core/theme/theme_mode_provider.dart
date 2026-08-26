import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key the selected theme mode is stored under. Absent
/// (or no matching entry) means "follow the system" — the same default
/// AppTheme had before this override existed.
const themeModeOverridePrefsKey = 'theme_mode_override';

/// The user's explicit light/dark/system choice, matching
/// [LocaleOverride]'s pattern exactly. Persisted to SharedPreferences so
/// the choice survives an app restart; the stored value must be loaded and
/// injected via [overrideWith] before `runApp` (see main.dart) so the
/// correct theme renders on the very first frame instead of flashing the
/// system theme first.
class ThemeModeOverride extends Notifier<ThemeMode> {
  final ThemeMode _initial;
  ThemeModeOverride([this._initial = ThemeMode.system]);

  @override
  ThemeMode build() => _initial;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeOverridePrefsKey, mode.name);
  }
}

/// Reads the persisted theme choice, for use before `runApp` — see
/// main.dart. Returns [ThemeMode.system] if nothing was stored.
Future<ThemeMode> loadStoredThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(themeModeOverridePrefsKey);
  return ThemeMode.values.firstWhere(
    (m) => m.name == raw,
    orElse: () => ThemeMode.system,
  );
}

final themeModeProvider = NotifierProvider<ThemeModeOverride, ThemeMode>(
  ThemeModeOverride.new,
);
