import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';
import '../domain/queue_entry.dart';

const _pageSize = 20;
const _activeStatuses = ['waiting', 'called', 'in_service'];

/// Wraps every Supabase call for the walk-in queue: `queue_entries` reads,
/// and the `add_walk_in`/`change_queue_status` RPC transactions. Queue
/// status must never be mutated with a raw update — always through
/// `change_queue_status`, which is what recalculates downstream wait
/// estimates (supabase/migrations/0010_features_completion.sql). That RPC —
/// like `add_walk_in` — requires connectivity and is never queued offline
/// (spec slide 9: queue-status changes stay on the critical path).
///
/// `queue_entries`/`customers` are tables [WorkspaceMirror] keeps warm for
/// offline reading — `listActive`/`listCustomerIdName` fall back to that
/// cache when the live fetch fails. The mirror only stores flat rows (no
/// join), so a cache-fallback [QueueEntry] has null customer/service/staff
/// names — acceptable for a read-only offline view of queue position/wait.
class QueueRepository {
  final SupabaseClient client;
  final LocalStore localStore;
  QueueRepository(this.client, this.localStore);

  Future<List<QueueEntry>> listActive(String organizationId, {int page = 0}) async {
    try {
      final rows = await client
          .from('queue_entries')
          .select('*,customers(name),services(name),staff(display_name)')
          .eq('organization_id', organizationId)
          .inFilter('status', _activeStatuses)
          .order('queue_number')
          .range(page * _pageSize, page * _pageSize + _pageSize - 1);
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(QueueEntry.fromRow).toList();
    } catch (_) {
      final cached = await localStore.list('queue_entries');
      final active = cached
          .where(
            (r) =>
                r['organization_id'] == organizationId &&
                _activeStatuses.contains(r['status']),
          )
          .toList()
        ..sort(
          (a, b) => (a['queue_number'] as num).compareTo(b['queue_number'] as num),
        );
      return active
          .skip(page * _pageSize)
          .take(_pageSize)
          .map(QueueEntry.fromRow)
          .toList();
    }
  }

  /// Lightweight id+name projection for the walk-in dialog's customer picker.
  Future<List<Map<String, dynamic>>> listCustomerIdName(
    String organizationId,
  ) async {
    try {
      final rows = await client
          .from('customers')
          .select('id,name')
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null)
          .order('name');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      final cached = await localStore.list('customers');
      return cached
          .where(
            (r) =>
                r['organization_id'] == organizationId &&
                r['deleted_at'] == null,
          )
          .map((r) => {'id': r['id'], 'name': r['name']})
          .toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    }
  }

  Future<dynamic> addWalkIn({
    required String customerId,
    required String serviceId,
    String? staffId,
  }) => client.rpc(
    'add_walk_in',
    params: {'p_customer': customerId, 'p_service': serviceId, 'p_staff': staffId},
  );

  Future<void> changeStatus({required String queueId, required String status}) =>
      client.rpc(
        'change_queue_status',
        params: {'p_queue': queueId, 'p_status': status},
      );

  /// Opens a Realtime channel on `queue_entries` for [organizationId],
  /// invoking [onChange] for any insert/update/delete — so a staff member
  /// with the Queue page open sees a walk-in added by someone else without
  /// needing to manually refresh, matching calendar_page.dart's subscribe()
  /// for `appointments`. Caller owns the returned channel's lifecycle
  /// (unsubscribe/remove on dispose).
  RealtimeChannel subscribe(String organizationId, void Function() onChange) {
    return client
        .channel('queue-$organizationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'queue_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: organizationId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}

final queueRepositoryProvider = Provider<QueueRepository>(
  (ref) => QueueRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);

const queuePageSize = _pageSize;
