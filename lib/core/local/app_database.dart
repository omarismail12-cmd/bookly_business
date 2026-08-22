import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens (and lazily migrates) the on-device SQLite database backing
/// [LocalStore]/[SyncQueueStore]. Native platforms only (Android, iOS,
/// Windows, macOS, Linux) — see the class doc on
/// `firebase_notification_service.dart` for why the same "no web" scoping
/// applies here: `sqlite3`/`sqlite3_flutter_libs` need a native library,
/// which web doesn't have without a separate WASM asset pipeline this
/// project doesn't set up. Callers must check `kIsWeb` before touching this.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}bookly_business_local.sqlite';
    final db = sqlite3.open(path);

    db.execute('''
      CREATE TABLE IF NOT EXISTS local_store (
        table_name TEXT NOT NULL,
        id TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (table_name, id)
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        operation_id TEXT PRIMARY KEY,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        error TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    _db = db;
    return db;
  }
}
