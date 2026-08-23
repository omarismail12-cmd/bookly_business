import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_provider.dart';
import '../local/local_store.dart';
import '../local/local_store_provider.dart';

/// Pulls a read-only local-first mirror of the active workspace (spec slide
/// 9: "local-first mirror... enough for the app to render the calendar,
/// queue, and customer list while offline"). Deliberately narrow, matching
/// [SyncService]'s own scope note: this only ever *reads* from Supabase and
/// upserts into [LocalStore] — it never writes back, and it never touches
/// payments. Booking/payment/queue-status *writes* still require
/// connectivity and go through their RPCs exactly as before; this class
/// only makes the corresponding *reads* survive being offline.
class WorkspaceMirror {
  final SupabaseClient client;
  final LocalStore store;
  WorkspaceMirror(this.client, this.store);

  /// Tables this mirror keeps warm — the ones the spec calls out by name.
  static const mirroredTables = [
    'appointments',
    'queue_entries',
    'customers',
    'services',
    'staff',
  ];

  /// Refreshes the local mirror for [organizationId] from the live backend.
  /// Safe to call opportunistically (on reconnect, periodically, on tab
  /// open) — each table is fetched independently and a failure on one
  /// (typically: still offline) just leaves that table's existing cache in
  /// place rather than throwing.
  Future<void> refresh(String organizationId) async {
    final windowStart = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final windowEnd = windowStart.add(const Duration(days: 15));

    await _mirror(
      'appointments',
      () => client
          .from('appointments')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null)
          .gte('starts_at', windowStart.toIso8601String())
          .lt('starts_at', windowEnd.toIso8601String()),
    );

    await _mirror(
      'queue_entries',
      () => client
          .from('queue_entries')
          .select()
          .eq('organization_id', organizationId)
          .inFilter('status', ['waiting', 'called', 'in_service']),
    );

    await _mirror(
      'customers',
      () => client
          .from('customers')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null)
          .order('name')
          .limit(200),
    );

    await _mirror(
      'services',
      () => client
          .from('services')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null),
    );

    await _mirror(
      'staff',
      () => client
          .from('staff')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null),
    );
  }

  Future<void> _mirror(
    String table,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) async {
    try {
      final rows = await fetch();
      for (final row in rows) {
        await store.put(table, row['id'] as String, row);
      }
    } catch (_) {
      // Offline, or the request failed: keep serving whatever was cached
      // from the last successful refresh instead of throwing.
    }
  }

  /// Cached rows for [table] belonging to [organizationId] — the offline
  /// fallback repositories reach for when a live fetch fails.
  Future<List<Map<String, dynamic>>> cached(
    String table,
    String organizationId,
  ) async {
    final rows = await store.list(table);
    return rows.where((r) => r['organization_id'] == organizationId).toList();
  }
}

final workspaceMirrorProvider = Provider<WorkspaceMirror>(
  (ref) => WorkspaceMirror(ref.watch(supabaseProvider), ref.watch(localStoreProvider)),
);
