import 'sync_models.dart';

/// Durable sync queue contract required by Phase 6.
/// Replace the current in-memory queue with a Drift-backed implementation.
abstract interface class SyncQueueStore {
  Future<void> enqueue(SyncOperation operation);
  Future<List<SyncOperation>> pending();
  Future<void> markSynced(String operationId);
  Future<void> markFailed(String operationId, String error);
  Future<int> pendingCount();
}
