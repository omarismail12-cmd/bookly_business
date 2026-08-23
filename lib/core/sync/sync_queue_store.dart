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

  /// Marks a queued non-financial edit as conflicted: the row's `version`
  /// moved server-side between when the edit was queued and when drain()
  /// tried to apply it (Phase 2 conflict handling). [serverSnapshotJson] is
  /// the server's current row, stashed so the resolution UI can show
  /// "theirs" without a second round trip.
  Future<void> markConflict(String operationId, String serverSnapshotJson);

  /// Operations awaiting a user's "keep mine / keep theirs" decision — never
  /// retried by [pending]/drain on its own.
  Future<List<SyncOperation>> conflicted();
  Future<int> conflictCount();

  /// User chose "keep mine": re-queues the operation with a flag telling
  /// drain() to apply it unconditionally next time, skipping the version
  /// check that produced the conflict.
  Future<void> resolveKeepMine(String operationId);

  /// User chose "keep theirs": drops the queued edit — the server's current
  /// value wins and nothing is retried.
  Future<void> resolveKeepTheirs(String operationId);
}
