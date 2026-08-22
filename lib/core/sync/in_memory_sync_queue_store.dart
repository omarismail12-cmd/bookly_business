import 'sync_models.dart';
import 'sync_queue_store.dart';

/// Web fallback: sqlite3 needs `dart:ffi`, which doesn't exist on the web
/// compiler target at all — not even behind a runtime check, since an
/// unreachable import still has to compile. See
/// `sync_queue_store_factory.dart` for the conditional-import switch that
/// keeps this file (and not sqlite3) in the web build's import graph.
/// Same [SyncQueueStore] contract as [SqliteSyncQueueStore], just not
/// durable across a page reload — acceptable because web sessions are
/// short-lived and connectivity is rarely the problem class this exists for.
class InMemorySyncQueueStore implements SyncQueueStore {
  final List<SyncOperation> _ops = [];

  @override
  Future<void> enqueue(SyncOperation operation) async {
    if (!_ops.any((o) => o.operationId == operation.operationId)) {
      _ops.add(operation);
    }
  }

  @override
  Future<List<SyncOperation>> pending() async =>
      _ops.where((o) => o.status == 'pending').toList();

  @override
  Future<void> markSynced(String operationId) async {
    _ops.firstWhere((o) => o.operationId == operationId).status = 'synced';
  }

  @override
  Future<void> markFailed(String operationId, String error) async {
    final op = _ops.firstWhere((o) => o.operationId == operationId);
    op.retryCount++;
    op.status = op.retryCount >= 5 ? 'failed' : 'pending';
  }

  @override
  Future<int> pendingCount() async =>
      _ops.where((o) => o.status == 'pending').length;
}
