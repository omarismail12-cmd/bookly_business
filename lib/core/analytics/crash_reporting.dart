abstract interface class CrashReporting {
  Future<void> initialize();
  Future<void> recordError(Object error, StackTrace stackTrace, {String? reason});
  Future<void> setUser(String? userId);
}

/// See [FirebaseCrashReporting] in this folder for the concrete Firebase
/// Crashlytics adapter — a safe no-op until a real Firebase project is
/// configured for the current platform.
