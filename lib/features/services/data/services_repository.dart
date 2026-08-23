import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/service.dart';

/// Wraps every Supabase call for the `services` table. Presentation code
/// must go through this instead of calling `Supabase.instance.client`
/// directly, so RLS-respecting query shape lives in one place per feature
/// (mirrors OrganizationRepository's style in
/// lib/features/organisations/data/organization_repository.dart).
///
/// `services` is one of the tables [WorkspaceMirror] keeps warm for offline
/// reading (spec slide 9). `listActive`/`listIdName` fall back to that
/// cache when the live fetch fails — reads only; creating or editing a
/// service still needs connectivity, except for the description field
/// (see [ServicesRepository]'s queued update, wired from services_page.dart
/// through SyncService, matching the pattern customers_page.dart already
/// established for private-notes-style edits).
class ServicesRepository {
  final SupabaseClient client;
  final LocalStore localStore;
  final SyncService syncService;
  ServicesRepository(this.client, this.localStore, this.syncService);

  Future<List<Service>> listActive(String organizationId) async {
    try {
      final rows = await client
          .from('services')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null)
          .order('name');
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(Service.fromRow).toList();
    } catch (_) {
      final cached = await _cachedRows(organizationId);
      cached.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return cached.map(Service.fromRow).toList();
    }
  }

  /// Lightweight id+name projection for pickers (packages/queue dropdowns).
  Future<List<Map<String, dynamic>>> listIdName(String organizationId) async {
    try {
      final rows = await client
          .from('services')
          .select('id,name')
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null)
          .order('name');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      final cached = await _cachedRows(organizationId);
      return cached
          .map((r) => {'id': r['id'], 'name': r['name']})
          .toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    }
  }

  Future<List<Map<String, dynamic>>> _cachedRows(String organizationId) async {
    final rows = await localStore.list('services');
    return rows
        .where(
          (r) =>
              r['organization_id'] == organizationId &&
              r['deleted_at'] == null,
        )
        .toList();
  }

  Future<void> create({
    required String organizationId,
    required String name,
    required int durationMin,
    required int bufferMin,
    required int priceMinor,
    required int depositRequiredMinor,
  }) => client.from('services').insert({
    'organization_id': organizationId,
    'name': name,
    'duration_min': durationMin,
    'buffer_min': bufferMin,
    'price_minor': priceMinor,
    'deposit_required_minor': depositRequiredMinor,
  });

  Future<void> softDelete(String id) => client
      .from('services')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  /// Local-first, conflict-checked edit (spec slide 9): queues through
  /// [SyncService] rather than writing straight to Supabase, so editing a
  /// description works offline. [baseVersion] is the service's `version`
  /// column as last loaded — if the server's version has moved by the time
  /// this drains, SyncService parks it as a conflict instead of
  /// overwriting silently (see SyncService._applyVersionedUpdate).
  Future<void> updateDescription({
    required String serviceId,
    required String? description,
    required int baseVersion,
  }) async {
    await syncService.enqueue(
      SyncOperation(
        operationId: const Uuid().v4(),
        entity: 'services',
        entityId: serviceId,
        operation: 'update_service_description',
        payload: {'description': description, '_base_version': baseVersion},
      ),
    );
    await syncService.drain();
  }
}

final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
    ref.watch(syncServiceProvider),
  ),
);
