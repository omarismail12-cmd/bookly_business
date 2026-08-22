import 'sync_models.dart';

/// Durable sync queue contract required by Phase 6.
/// Replace the current in-memory queue with a Drift-backed implementation.
abstract interface class SyncQueueStore {
  Future<void> enqueue(SyncOperation operation);
  Future<List<SyncOperation>> pending();
  Future<void> markSynced(String operationId);
  Future<void> markFailed(String operationId, String error);
  Future<int> pendingCount();

  /// Operations that exhausted their automatic retries (see [markFailed])
  /// and need an explicit user-triggered retry — never re-attempted by
  /// [pending]/drain on its own, so they must stay visible somewhere or a
  /// failed offline write silently disappears.
  Future<int> failedCount();

  /// Moves every 'failed' operation back to 'pending' with a reset retry
  /// count, so the next drain() picks it up again. Called by a user-facing
  /// "Retry failed" action.
  Future<void> resetFailed();
}
