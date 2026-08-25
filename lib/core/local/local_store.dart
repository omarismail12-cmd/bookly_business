/// Phase 6 local persistence boundary.
///
/// Backed by a raw `sqlite3`-based implementation on native platforms
/// ([SqliteLocalStore]) and `localStorage` on web ([InMemoryLocalStore]) —
/// see local_store_factory.dart. Not Drift-backed: Drift's codegen is
/// unresolvable under this project's pinned Dart SDK. Keeping this boundary
/// separate prevents widgets/controllers from knowing whether data is local
/// or remote.
abstract interface class LocalStore {
  Future<void> put(String table, String id, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> get(String table, String id);
  Future<List<Map<String, dynamic>>> list(String table);
  Future<void> delete(String table, String id);
}
