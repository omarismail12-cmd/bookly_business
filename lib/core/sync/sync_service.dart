import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "sync_models.dart";
import "sync_queue_store.dart";
import "sync_queue_store_factory.dart";

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(Supabase.instance.client, createSyncQueueStore());
  ref.onDispose(service.dispose);
  return service;
});

/// Local-first write path for the small set of entities safe to create
/// offline (spec slide 9). Deliberately narrow: booking/payments/loyalty
/// stay server-authoritative through their RPCs (spec's own rule —
/// "Financial actions handled by RPC transaction") and are never queued
/// here. Only customer create/update — a plain CRUD record with no
/// concurrency or money semantics — goes through this path today.
///
/// The actual [SyncQueueStore] is picked by [createSyncQueueStore]
/// (sqlite3-backed on native platforms, in-memory on web — see
/// sync_queue_store_factory.dart for why that has to be a compile-time
/// conditional import, not a runtime kIsWeb branch).
///
/// [pendingCount] is a [ValueListenable] so UI (an offline banner, a
/// pending-sync badge) can react without polling.
class SyncService {
  final SupabaseClient client;
  final SyncQueueStore store;
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  SyncService(this.client, this.store) {
    _refreshPendingCount();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) drain();
    });
  }

  Future<void> enqueue(SyncOperation op) async {
    await store.enqueue(op);
    await _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    pendingCount.value = await store.pendingCount();
  }

  Future<void> drain() async {
    for (final op in await store.pending()) {
      try {
        switch (op.operation) {
          case 'create_customer':
            await client.from('customers').upsert(op.payload);
          case 'update_customer':
            await client
                .from('customers')
                .update(op.payload)
                .eq('id', op.entityId);
          default:
            // Unknown operation kind: nothing to retry into, drop it as
            // synced rather than retrying forever.
            break;
        }
        await store.markSynced(op.operationId);
      } catch (e) {
        await store.markFailed(op.operationId, '$e');
      }
    }
    await _refreshPendingCount();
  }

  void dispose() {
    _sub?.cancel();
    pendingCount.dispose();
  }
}
