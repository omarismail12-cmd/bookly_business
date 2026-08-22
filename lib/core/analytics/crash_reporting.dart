abstract interface class CrashReporting {
  Future<void> initialize();
  Future<void> recordError(Object error, StackTrace stackTrace, {String? reason});
  Future<void> setUser(String? userId);
}

/// Concrete Firebase Crashlytics adapter belongs here after Firebase platform
/// configuration is added.
