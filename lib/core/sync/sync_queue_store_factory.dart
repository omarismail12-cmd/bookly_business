// Conditional import: `dart.library.io` is true on Android/iOS/Windows/
// macOS/Linux (native, has dart:io) and false on web. This is the standard
// Dart way to keep an FFI-dependent package (sqlite3) entirely out of the
// web compiler's import graph — a runtime `kIsWeb` check is NOT enough,
// since an unreachable import still has to compile.
export 'sync_queue_store_web.dart'
    if (dart.library.io) 'sync_queue_store_native.dart';
