import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class BooklyApp extends StatelessWidget {
  const BooklyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Bookly Business',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localeResolutionCallback: (locale, supported) => supported.firstWhere(
      (x) => x.languageCode == locale?.languageCode,
      orElse: () => supported.first,
    ),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: appRouter,
  );
}
