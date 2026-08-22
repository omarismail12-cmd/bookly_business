import 'dart:convert';

import 'app_database.dart';
import 'local_store.dart';

/// SQLite-backed [LocalStore]. Generic JSON-blob storage keyed by
/// (table, id) rather than per-entity generated tables — this project's
/// Dart SDK pin makes drift's code generator unresolvable (drift_dev pulls
/// an analyzer version flutter_riverpod/flutter_test can't share under
/// Dart 3.10.4; see the note in pubspec.yaml history / final report), so
/// this uses the `sqlite3` package directly instead of drift. Functionally
/// equivalent for this project's needs: an offline read cache, not a
/// relational local database that needs joins.
class SqliteLocalStore implements LocalStore {
  @override
  Future<void> put(String table, String id, Map<String, dynamic> data) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      'INSERT INTO local_store(table_name, id, data, updated_at) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(table_name, id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at',
      [table, id, jsonEncode(data), DateTime.now().toIso8601String()],
    );
  }

  @override
  Future<Map<String, dynamic>?> get(String table, String id) async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      'SELECT data FROM local_store WHERE table_name = ? AND id = ?',
      [table, id],
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['data'] as String));
  }

  @override
  Future<List<Map<String, dynamic>>> list(String table) async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      'SELECT data FROM local_store WHERE table_name = ? ORDER BY updated_at DESC',
      [table],
    );
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['data'] as String)))
        .toList();
  }

  @override
  Future<void> delete(String table, String id) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      'DELETE FROM local_store WHERE table_name = ? AND id = ?',
      [table, id],
    );
  }
}
