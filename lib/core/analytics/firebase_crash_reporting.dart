import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporting.dart';

/// App-wide instance shared between `main.dart` (initialize + uncaught-error
/// capture) and any widget that wants to attach a user id, e.g. once org
/// membership loads.
final crashReporting = FirebaseCrashReporting();

/// Concrete [CrashReporting] adapter for Firebase Crashlytics.
///
/// Same defensive pattern as [FirebaseNotificationService]: without a
/// configured Firebase project, `Firebase.initializeApp()` throws and this
/// becomes a safe no-op instead of crashing the app it's meant to monitor.
/// Crashlytics is also unsupported on web and desktop, so [initialize]
/// no-ops there too rather than failing.
class FirebaseCrashReporting implements CrashReporting {
  bool _available = false;

  @override
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      _available = true;
    } catch (e) {
      _available = false;
      debugPrint(
        'Crashlytics unavailable: no Firebase project is configured for this platform ($e).',
      );
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    if (!_available) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
      );
    } catch (e) {
      debugPrint('Crashlytics recordError failed: $e');
    }
  }

  @override
  Future<void> setUser(String? userId) async {
    if (!_available) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (e) {
      debugPrint('Crashlytics setUser failed: $e');
    }
  }
}
