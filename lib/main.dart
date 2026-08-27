import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/analytics/firebase_crash_reporting.dart';
import 'core/config/app_config.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/theme_mode_provider.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Without this, go_router's web URL bar ignores context.push()/
      // pushReplacement()/replace() entirely — it keeps showing the base
      // route's URL while the Navigator displays the pushed page (verified
      // against go_router 17.5.0's own source: parser.dart's
      // restoreRouteInformation only reflects the pushed location when this
      // flag is set; router.dart defaults it to false "for backward
      // compatibility"). Every push() in this app targets a standalone,
      // independently deep-linkable top-level GoRoute (/login,
      // /customer/login, /book/:slug), so the tradeoff the flag's own
      // doc warns about — the pushed URL not being deeplink-able — doesn't
      // apply here.
      GoRouter.optionURLReflectsImperativeAPIs = true;
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
      final storedThemeMode = await loadStoredThemeMode();
      runApp(
        ProviderScope(
          overrides: [
            localeOverrideProvider.overrideWith(
              () => LocaleOverride(storedLocale),
            ),
            themeModeProvider.overrideWith(
              () => ThemeModeOverride(storedThemeMode),
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
