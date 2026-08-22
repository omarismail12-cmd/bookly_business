/// Phase 6 local persistence boundary.
///
/// The production implementation should be backed by Drift/SQLite. Keeping
/// this boundary separate prevents widgets/controllers from knowing whether
/// data is local or remote.
abstract interface class LocalStore {
  Future<void> put(String table, String id, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> get(String table, String id);
  Future<List<Map<String, dynamic>>> list(String table);
  Future<void> delete(String table, String id);
}
