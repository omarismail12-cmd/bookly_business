import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/gen/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class BooklyApp extends ConsumerWidget {
  const BooklyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeOverride = ref.watch(localeOverrideProvider);
    return MaterialApp.router(
      title: 'Bookly Business',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Non-null pins the app to that language; null falls back to
      // localeResolutionCallback's device-based resolution below.
      locale: localeOverride,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supported) => supported.firstWhere(
        (x) => x.languageCode == locale?.languageCode,
        orElse: () => supported.first,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: appRouter,
    );
  }
}
