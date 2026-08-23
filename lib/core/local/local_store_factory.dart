// Conditional import: mirrors sync_queue_store_factory.dart exactly —
// `dart.library.io` is true on native platforms (sqlite3 available), false
// on web, where LocalStore falls back to window.localStorage instead.
export 'local_store_web.dart' if (dart.library.io) 'local_store_native.dart';
