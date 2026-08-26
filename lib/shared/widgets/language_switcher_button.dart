import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/gen/app_localizations.dart';
import '../../core/localization/locale_provider.dart';

/// AppBar action that lets the user override the in-app language,
/// independent of the device locale. Selecting "System default" clears the
/// override so BooklyApp falls back to its usual device-locale resolution.
/// Shared between BusinessShell and CustomerShell so both portals offer the
/// same switcher.
class LanguageSwitcherButton extends ConsumerWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeOverrideProvider);
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.languageSwitcherTitle,
      icon: const Icon(Icons.language),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => SimpleDialog(
          title: Text(l10n.languageSwitcherTitle),
          children: [
            RadioGroup<Locale?>(
              groupValue: current,
              onChanged: (v) {
                ref.read(localeOverrideProvider.notifier).set(v);
                Navigator.pop(context);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<Locale?>(
                    title: Text(l10n.languageSystemDefault),
                    value: null,
                  ),
                  // Each language's own name is deliberately shown in its
                  // own script regardless of the current UI language (the
                  // same convention iOS/Android/WhatsApp use), so these two
                  // are not run through AppLocalizations.
                  const RadioListTile<Locale?>(
                    title: Text('English'),
                    value: Locale('en'),
                  ),
                  const RadioListTile<Locale?>(
                    title: Text('العربية'),
                    value: Locale('ar'),
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
