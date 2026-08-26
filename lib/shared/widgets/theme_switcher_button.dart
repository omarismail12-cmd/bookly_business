import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/gen/app_localizations.dart';
import '../../core/theme/theme_mode_provider.dart';

/// AppBar action that lets the user override the light/dark theme,
/// independent of the system setting. Mirrors LanguageSwitcherButton's
/// pattern exactly — same IconButton + SimpleDialog + RadioGroup shape —
/// and is shared between BusinessShell and CustomerShell for the same
/// reason that one is: both portals offer the same switcher.
class ThemeSwitcherButton extends ConsumerWidget {
  const ThemeSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.themeSwitcherTitle,
      icon: Icon(
        switch (current) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        },
      ),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => SimpleDialog(
          title: Text(l10n.themeSwitcherTitle),
          children: [
            RadioGroup<ThemeMode>(
              groupValue: current,
              onChanged: (v) {
                if (v != null) ref.read(themeModeProvider.notifier).set(v);
                Navigator.pop(context);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeSystem),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeLight),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(l10n.themeDark),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
