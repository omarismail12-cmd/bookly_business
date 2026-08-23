// This file is only ever compiled into the web build, selected exclusively
// via the conditional import in local_store_factory.dart — never imported
// into a native build. Same dart:html-via-window.localStorage rationale as
// in_memory_sync_queue_store.dart.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'local_store.dart';

const _storageKeyPrefix = 'bookly_local_store_v1_';

/// Web [LocalStore]: sqlite3 needs `dart:ffi`, unavailable on the web
/// compiler target. Backed by one `window.localStorage` entry per table —
/// this is a read-only offline mirror of a handful of tables
/// (appointments/queue_entries/customers/services/staff), not a general
/// database, so a JSON blob per table is enough. Same [LocalStore] contract
/// as [SqliteLocalStore].
class InMemoryLocalStore implements LocalStore {
  Map<String, dynamic> _readTable(String table) {
    try {
      final raw = html.window.localStorage['$_storageKeyPrefix$table'];
      if (raw == null || raw.isEmpty) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void _writeTable(String table, Map<String, dynamic> rows) {
    try {
      html.window.localStorage['$_storageKeyPrefix$table'] = jsonEncode(rows);
    } catch (_) {
      // Private browsing / storage quota exceeded: cache just won't
      // survive a reload, offline reads still work for this session.
    }
  }

  @override
  Future<void> put(String table, String id, Map<String, dynamic> data) async {
    final rows = _readTable(table);
    rows[id] = {...data, '_cached_at': DateTime.now().toIso8601String()};
    _writeTable(table, rows);
  }

  @override
  Future<Map<String, dynamic>?> get(String table, String id) async {
    final row = _readTable(table)[id];
    return row == null ? null : Map<String, dynamic>.from(row as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> list(String table) async {
    final rows = _readTable(table);
    final list = rows.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    list.sort(
      (a, b) => (b['_cached_at'] as String? ?? '').compareTo(
        a['_cached_at'] as String? ?? '',
      ),
    );
    return list;
  }

  @override
  Future<void> delete(String table, String id) async {
    final rows = _readTable(table);
    rows.remove(id);
    _writeTable(table, rows);
  }
}
