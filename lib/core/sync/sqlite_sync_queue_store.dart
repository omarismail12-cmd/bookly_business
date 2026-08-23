import 'dart:convert';

import '../local/app_database.dart';
import 'sync_models.dart';
import 'sync_queue_store.dart';

/// SQLite-backed [SyncQueueStore] — a durable outbox surviving app restarts,
/// matching the spec's sync_queue shape (slide 9: id, operation_id UNIQUE,
/// entity, entity_id, operation, payload JSONB, status, retry_count).
class SqliteSyncQueueStore implements SyncQueueStore {
  @override
  Future<void> enqueue(SyncOperation operation) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      'INSERT OR IGNORE INTO sync_queue(operation_id, entity, entity_id, operation, payload, status, retry_count, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        operation.operationId,
        operation.entity,
        operation.entityId,
        operation.operation,
        jsonEncode(operation.payload),
        operation.status,
        operation.retryCount,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  @override
  Future<List<SyncOperation>> pending() async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      "SELECT * FROM sync_queue WHERE status = 'pending' ORDER BY created_at",
    );
    return rows
        .map(
          (r) => SyncOperation(
            operationId: r['operation_id'] as String,
            entity: r['entity'] as String,
            entityId: r['entity_id'] as String,
            operation: r['operation'] as String,
            payload: Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
            retryCount: r['retry_count'] as int,
            status: r['status'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> markSynced(String operationId) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      "UPDATE sync_queue SET status = 'synced', error = NULL WHERE operation_id = ?",
      [operationId],
    );
  }

  @override
  Future<void> markFailed(String operationId, String error) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      "UPDATE sync_queue SET status = CASE WHEN retry_count + 1 >= 5 THEN 'failed' ELSE 'pending' END, "
      'retry_count = retry_count + 1, error = ? WHERE operation_id = ?',
      [error, operationId],
    );
  }

  @override
  Future<int> pendingCount() async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'pending'",
    );
    return rows.first['c'] as int;
  }

  @override
  Future<int> failedCount() async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'failed'",
    );
    return rows.first['c'] as int;
  }

  @override
  Future<void> resetFailed() async {
    final db = await AppDatabase.instance.open();
    db.execute(
      "UPDATE sync_queue SET status = 'pending', retry_count = 0, error = NULL WHERE status = 'failed'",
    );
  }

  @override
  Future<void> markConflict(String operationId, String serverSnapshotJson) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      "UPDATE sync_queue SET status = 'conflict', error = ? WHERE operation_id = ?",
      [serverSnapshotJson, operationId],
    );
  }

  @override
  Future<List<SyncOperation>> conflicted() async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      "SELECT * FROM sync_queue WHERE status = 'conflict' ORDER BY created_at",
    );
    return rows
        .map(
          (r) => SyncOperation(
            operationId: r['operation_id'] as String,
            entity: r['entity'] as String,
            entityId: r['entity_id'] as String,
            operation: r['operation'] as String,
            payload: Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
            retryCount: r['retry_count'] as int,
            status: r['status'] as String,
            detail: r['error'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<int> conflictCount() async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'conflict'",
    );
    return rows.first['c'] as int;
  }

  @override
  Future<void> resolveKeepMine(String operationId) async {
    final db = await AppDatabase.instance.open();
    final rows = db.select(
      'SELECT payload FROM sync_queue WHERE operation_id = ?',
      [operationId],
    );
    if (rows.isEmpty) return;
    final payload = Map<String, dynamic>.from(
      jsonDecode(rows.first['payload'] as String),
    )..['_force'] = true;
    db.execute(
      "UPDATE sync_queue SET status = 'pending', payload = ?, error = NULL WHERE operation_id = ?",
      [jsonEncode(payload), operationId],
    );
  }

  @override
  Future<void> resolveKeepTheirs(String operationId) async {
    final db = await AppDatabase.instance.open();
    db.execute(
      "UPDATE sync_queue SET status = 'synced', error = NULL WHERE operation_id = ?",
      [operationId],
    );
  }
}
