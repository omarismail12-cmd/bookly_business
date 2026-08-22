import 'package:flutter/material.dart';
import '../core/localization/gen/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class BooklyApp extends StatelessWidget {
  const BooklyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Bookly Business',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: (locale, supported) => supported.firstWhere(
      (x) => x.languageCode == locale?.languageCode,
      orElse: () => supported.first,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: appRouter,
  );
}
