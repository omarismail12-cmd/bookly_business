import "dart:async";
import "dart:convert";

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

/// Internal signal thrown by [SyncService._applyVersionedUpdate] when a
/// queued edit's captured `_base_version` no longer matches the server's
/// current `version` for that row. Caught by [SyncService.drain] so the
/// operation is left in `conflict` status (already recorded by
/// [SyncQueueStore.markConflict]) instead of being retried as a failure.
class _SyncConflict implements Exception {
  const _SyncConflict();
}

/// Local-first write path for the entities safe to create/edit offline
/// (spec slide 9). Two tiers:
///
///  - Booking creation, payments and queue status changes stay
///    server-authoritative through their RPCs (`create_booking`,
///    `record_payment`, `change_queue_status`, ...) and are NEVER queued
///    here — those need a real transaction (the exclusion constraint,
///    idempotency key, wait-recalculation trigger) that a client-side
///    upsert can't reproduce, and the spec's own rule is explicit:
///    "Financial actions handled by RPC transaction." Attempting one
///    offline should fail loudly, not silently queue and apply later.
///  - Everything else queued here is a plain non-financial, non-booking
///    field edit (customer private notes, a service's description) or an
///    upsert with no money/booking semantics (staff working hours/breaks).
///    Those are safe to apply whenever connectivity returns.
///
/// Customer/service edits carry a `_base_version` (the row's `version`
/// column at the moment the edit was queued) in their payload — see
/// [_applyVersionedUpdate]. If the server's version has moved by the time
/// [drain] gets to it, that's a genuine conflict (someone else edited the
/// same row first) and the operation is parked in `conflict` status for the
/// user to resolve (keep mine / keep theirs) rather than silently
/// overwritten. Working-hours/breaks upserts have no `version` column to
/// compare against at all (see supabase/migrations/0001_foundation.sql), so
/// those stay last-write-wins with no conflict detection — there's nothing
/// to detect a conflict against.
///
/// The actual [SyncQueueStore] is picked by [createSyncQueueStore]
/// (sqlite3-backed on native platforms, in-memory on web — see
/// sync_queue_store_factory.dart for why that has to be a compile-time
/// conditional import, not a runtime kIsWeb branch).
///
/// [pendingCount]/[failedCount]/[conflictCount] are [ValueListenable]s so UI
/// (an offline banner, a pending-sync badge, a conflict resolver) can react
/// without polling.
class SyncService {
  final SupabaseClient client;
  final SyncQueueStore store;
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<int> failedCount = ValueNotifier(0);
  final ValueNotifier<int> conflictCount = ValueNotifier(0);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  SyncService(this.client, this.store) {
    _refreshCounts();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) drain();
    });
  }

  Future<void> enqueue(SyncOperation op) async {
    await store.enqueue(op);
    await _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    pendingCount.value = await store.pendingCount();
    failedCount.value = await store.failedCount();
    conflictCount.value = await store.conflictCount();
  }

  Future<void> drain() async {
    for (final op in await store.pending()) {
      try {
        switch (op.operation) {
          case 'create_customer':
            await client.from('customers').upsert(op.payload);
          case 'update_customer_notes':
            // Covers both customer-facing private notes (edited from
            // customer_detail_dialog.dart) and staff's next-visit
            // recommendation (edited from
            // staff_appointment_detail_page.dart) — same customers row,
            // same version, so one queued edit is enough even when a
            // caller only sends one of the two fields.
            await _applyVersionedUpdate(
              op,
              table: 'customers',
              fields: {
                if (op.payload.containsKey('private_notes'))
                  'private_notes': op.payload['private_notes'],
                if (op.payload.containsKey('next_recommendation'))
                  'next_recommendation': op.payload['next_recommendation'],
              },
            );
          case 'update_service_description':
            await _applyVersionedUpdate(
              op,
              table: 'services',
              fields: {'description': op.payload['description']},
            );
          case 'upsert_working_hours':
            await client
                .from('working_hours')
                .upsert(_stripSyncKeys(op.payload), onConflict: 'staff_id,weekday');
          case 'upsert_staff_break':
            await client
                .from('staff_breaks')
                .upsert(_stripSyncKeys(op.payload), onConflict: 'staff_id,weekday');
          default:
            // Unknown operation kind: nothing to retry into, drop it as
            // synced rather than retrying forever.
            break;
        }
        await store.markSynced(op.operationId);
      } on _SyncConflict {
        // Already recorded via store.markConflict inside
        // _applyVersionedUpdate — leave it there for the user to resolve,
        // don't mark synced or failed.
      } catch (e) {
        await store.markFailed(op.operationId, '$e');
      }
    }
    await _refreshCounts();
  }

  /// Applies [fields] to `$table` where id = op.entityId, but only after
  /// confirming the row hasn't moved since the edit was queued — unless the
  /// user already resolved a prior conflict with "keep mine" (payload
  /// `_force: true`), which skips the check and overwrites unconditionally.
  Future<void> _applyVersionedUpdate(
    SyncOperation op, {
    required String table,
    required Map<String, dynamic> fields,
  }) async {
    final force = op.payload['_force'] == true;
    if (!force) {
      final baseVersion = op.payload['_base_version'] as int?;
      if (baseVersion != null) {
        final current = await client
            .from(table)
            .select()
            .eq('id', op.entityId)
            .maybeSingle();
        final currentVersion = (current?['version'] as num?)?.toInt();
        if (current != null &&
            currentVersion != null &&
            currentVersion != baseVersion) {
          await store.markConflict(op.operationId, jsonEncode(current));
          throw const _SyncConflict();
        }
      }
    }
    await client.from(table).update(fields).eq('id', op.entityId);
  }

  /// Drops the sync-machinery-only keys (`_base_version`, `_force`) before
  /// a payload is sent to Supabase — those columns don't exist on any
  /// table.
  Map<String, dynamic> _stripSyncKeys(Map<String, dynamic> payload) =>
      {...payload}..removeWhere((k, _) => k.startsWith('_'));

  /// Operations parked in `conflict` status, awaiting a user decision.
  Future<List<SyncOperation>> conflicts() => store.conflicted();

  /// User chose "keep mine": re-applies the queued edit unconditionally on
  /// the next drain, overwriting whatever the server has now.
  Future<void> resolveConflictKeepMine(String operationId) async {
    await store.resolveKeepMine(operationId);
    await _refreshCounts();
    await drain();
  }

  /// User chose "keep theirs": drops the queued edit — the server's current
  /// value stands.
  Future<void> resolveConflictKeepTheirs(String operationId) async {
    await store.resolveKeepTheirs(operationId);
    await _refreshCounts();
  }

  /// Gives operations that exhausted their automatic retries (status
  /// 'failed') a fresh set of attempts, then immediately drains them —
  /// the only way a failed offline write ever gets un-stuck, since [drain]
  /// itself only ever looks at 'pending' rows.
  Future<void> retryFailed() async {
    await store.resetFailed();
    await drain();
  }

  void dispose() {
    _sub?.cancel();
    pendingCount.dispose();
    failedCount.dispose();
    conflictCount.dispose();
  }
}
