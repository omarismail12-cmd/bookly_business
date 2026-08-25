import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../domain/location.dart';

/// Wraps every Supabase call for the `locations` table. Presentation code
/// must go through this instead of calling `Supabase.instance.client`
/// directly, so RLS-respecting query shape lives in one place per feature.
///
/// Unlike `staff`/`customers`/`services`, `locations` is not one of the
/// tables [WorkspaceMirror] keeps warm (see workspace_mirror.dart), so this
/// repository has no offline cache fallback — same as the original
/// locations_page.dart, which surfaced a live fetch failure as an error
/// rather than silently falling back to stale data.
class LocationsRepository {
  final SupabaseClient client;
  LocationsRepository(this.client);

  Future<List<Location>> listActive(String organizationId) async {
    final rows = await client
        .from('locations')
        .select()
        .eq('organization_id', organizationId)
        .isFilter('deleted_at', null)
        .order('name');
    return List<Map<String, dynamic>>.from(rows).map(Location.fromRow).toList();
  }

  /// Lightweight id+name projection for pickers (booking_page.dart's
  /// location dropdown).
  Future<List<Map<String, dynamic>>> listIdNameActive(
    String organizationId,
  ) async {
    final rows = await client
        .from('locations')
        .select('id,name')
        .eq('organization_id', organizationId)
        .isFilter('deleted_at', null)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> create({
    required String organizationId,
    required String name,
    String? address,
    required String timezone,
  }) => client.from('locations').insert({
    'organization_id': organizationId,
    'name': name,
    'address': address,
    'timezone': timezone,
  });

  Future<void> update({
    required String id,
    required String name,
    String? address,
    required String timezone,
  }) => client.from('locations').update({
    'name': name,
    'address': address,
    'timezone': timezone,
  }).eq('id', id);

  Future<void> softDelete(String id) => client
      .from('locations')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);
}

final locationsRepositoryProvider = Provider<LocationsRepository>(
  (ref) => LocationsRepository(ref.watch(supabaseProvider)),
);
