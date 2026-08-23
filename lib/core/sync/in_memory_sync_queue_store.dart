// This file is only ever compiled into the web build, selected exclusively
// via the conditional import in sync_queue_store_factory.dart — never
// imported into a native build. dart:html is the correct tool for a small
// synchronous localStorage read/write here; migrating to package:web +
// dart:js_interop is a real option later but adds a dependency and
// significant verbosity for no behavior change today.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'sync_models.dart';
import 'sync_queue_store.dart';

const _storageKey = 'bookly_sync_queue_v1';

/// Web [SyncQueueStore]: sqlite3 needs `dart:ffi`, which doesn't exist on
/// the web compiler target at all — not even behind a runtime check, since
/// an unreachable import still has to compile. See
/// `sync_queue_store_factory.dart` for the conditional-import switch that
/// keeps this file (and not sqlite3) in the web build's import graph.
///
/// Backed by `window.localStorage` (not IndexedDB — a single JSON blob
/// under one key is enough for a queue that's realistically a handful of
/// pending customer writes) so a queued offline write survives a page
/// reload, not just an in-memory session. Same [SyncQueueStore] contract as
/// [SqliteSyncQueueStore].
class InMemorySyncQueueStore implements SyncQueueStore {
  final List<SyncOperation> _ops = [];

  InMemorySyncQueueStore() {
    _hydrate();
  }

  void _hydrate() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List;
      _ops.addAll(
        decoded.map(
          (e) => SyncOperation(
            operationId: e['operationId'] as String,
            entity: e['entity'] as String,
            entityId: e['entityId'] as String,
            operation: e['operation'] as String,
            payload: Map<String, dynamic>.from(e['payload'] as Map),
            retryCount: e['retryCount'] as int? ?? 0,
            status: e['status'] as String? ?? 'pending',
            detail: e['detail'] as String?,
          ),
        ),
      );
    } catch (_) {
      // Corrupt/foreign localStorage value: start with an empty queue
      // rather than crashing the app on boot.
    }
  }

  void _persist() {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(
        _ops
            .map(
              (o) => {
                'operationId': o.operationId,
                'entity': o.entity,
                'entityId': o.entityId,
                'operation': o.operation,
                'payload': o.payload,
                'retryCount': o.retryCount,
                'status': o.status,
                'detail': o.detail,
              },
            )
            .toList(),
      );
    } catch (_) {
      // Private browsing / storage quota exceeded: the queue still works
      // for the rest of this session, it just won't survive a reload.
    }
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    if (!_ops.any((o) => o.operationId == operation.operationId)) {
      _ops.add(operation);
      _persist();
    }
  }

  @override
  Future<List<SyncOperation>> pending() async =>
      _ops.where((o) => o.status == 'pending').toList();

  @override
  Future<void> markSynced(String operationId) async {
    _ops.firstWhere((o) => o.operationId == operationId).status = 'synced';
    _persist();
  }

  @override
  Future<void> markFailed(String operationId, String error) async {
    final op = _ops.firstWhere((o) => o.operationId == operationId);
    op.retryCount++;
    op.status = op.retryCount >= 5 ? 'failed' : 'pending';
    _persist();
  }

  @override
  Future<int> pendingCount() async =>
      _ops.where((o) => o.status == 'pending').length;

  @override
  Future<int> failedCount() async =>
      _ops.where((o) => o.status == 'failed').length;

  @override
  Future<void> resetFailed() async {
    for (final op in _ops.where((o) => o.status == 'failed')) {
      op.status = 'pending';
      op.retryCount = 0;
    }
    _persist();
  }

  @override
  Future<void> markConflict(String operationId, String serverSnapshotJson) async {
    final op = _ops.firstWhere((o) => o.operationId == operationId);
    op.status = 'conflict';
    op.detail = serverSnapshotJson;
    _persist();
  }

  @override
  Future<List<SyncOperation>> conflicted() async =>
      _ops.where((o) => o.status == 'conflict').toList();

  @override
  Future<int> conflictCount() async =>
      _ops.where((o) => o.status == 'conflict').length;

  @override
  Future<void> resolveKeepMine(String operationId) async {
    final op = _ops.firstWhere((o) => o.operationId == operationId);
    op.payload['_force'] = true;
    op.status = 'pending';
    op.detail = null;
    _persist();
  }

  @override
  Future<void> resolveKeepTheirs(String operationId) async {
    final op = _ops.firstWhere((o) => o.operationId == operationId);
    op.status = 'synced';
    op.detail = null;
    _persist();
  }
}
