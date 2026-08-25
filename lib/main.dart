import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/analytics/firebase_crash_reporting.dart';
import 'core/config/app_config.dart';
import 'core/localization/locale_provider.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Safe no-op until a real Firebase project is configured for this
      // platform — see FirebaseCrashReporting's class doc.
      await crashReporting.initialize();
      if (!AppConfig.isConfigured) {
        runApp(const ProviderScope(child: ConfigMissingApp()));
        return;
      }
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      // Loaded before the first frame so the app renders in the user's
      // previously-chosen language immediately, instead of flashing the
      // device locale first and then switching once this resolves.
      final storedLocale = await loadStoredLocaleOverride();
      runApp(
        ProviderScope(
          overrides: [
            localeOverrideProvider.overrideWith(
              () => LocaleOverride(storedLocale),
            ),
          ],
          child: const BooklyApp(),
        ),
      );
    },
    (error, stackTrace) {
      crashReporting.recordError(error, stackTrace);
    },
  );
}

class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase configuration is missing. Run Flutter with SUPABASE_URL and SUPABASE_ANON_KEY.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
