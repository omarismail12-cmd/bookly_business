import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return IconButton(
      tooltip: 'Language',
      icon: const Icon(Icons.language),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Language'),
          children: [
            RadioGroup<Locale?>(
              groupValue: current,
              onChanged: (v) {
                ref.read(localeOverrideProvider.notifier).set(v);
                Navigator.pop(context);
              },
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<Locale?>(
                    title: Text('System default'),
                    value: null,
                  ),
                  RadioListTile<Locale?>(
                    title: Text('English'),
                    value: Locale('en'),
                  ),
                  RadioListTile<Locale?>(
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
