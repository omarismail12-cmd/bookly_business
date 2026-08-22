import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const ProviderScope(child: _ConfigMissingApp()));
    return;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: BooklyApp()));
}

class _ConfigMissingApp extends StatelessWidget {
  const _ConfigMissingApp();
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
