import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';
import '../domain/staff_member.dart';

/// Wraps every Supabase call for the `staff` table and staff role
/// assignment. Presentation code must go through this instead of calling
/// `Supabase.instance.client` directly, so RLS-respecting query shape lives
/// in one place per feature.
///
/// `staff` is one of the tables [WorkspaceMirror] keeps warm for offline
/// reading (spec slide 9) — `listActive`/`listIdNameActive` fall back to
/// that cache when the live fetch fails. Writes (create/role assignment)
/// are unchanged and still require connectivity.
class StaffRepository {
  final SupabaseClient client;
  final LocalStore localStore;
  StaffRepository(this.client, this.localStore);

  Future<List<StaffMember>> listActive(String organizationId) async {
    try {
      final rows = await client
          .from('staff')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null)
          .order('display_name');
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(StaffMember.fromRow).toList();
    } catch (_) {
      final cached = await _cachedRows(organizationId);
      cached.sort(
        (a, b) =>
            (a['display_name'] as String).compareTo(b['display_name'] as String),
      );
      return cached.map(StaffMember.fromRow).toList();
    }
  }

  /// Lightweight id+name projection for pickers (queue "any staff" dropdown).
  Future<List<Map<String, dynamic>>> listIdNameActive(
    String organizationId,
  ) async {
    try {
      final rows = await client
          .from('staff')
          .select('id,display_name')
          .eq('organization_id', organizationId)
          .eq('status', 'active')
          .order('display_name');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      final cached = await _cachedRows(organizationId);
      return cached
          .where((r) => r['status'] == 'active')
          .map((r) => {'id': r['id'], 'display_name': r['display_name']})
          .toList()
        ..sort(
          (a, b) => (a['display_name'] as String).compareTo(
            b['display_name'] as String,
          ),
        );
    }
  }

  Future<List<Map<String, dynamic>>> _cachedRows(String organizationId) async {
    final rows = await localStore.list('staff');
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
    required String displayName,
  }) => client.from('staff').insert({
    'organization_id': organizationId,
    'display_name': displayName,
  });

  Future<void> softDelete(String id) => client
      .from('staff')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  Future<void> assignRoleByEmail({
    required String organizationId,
    required String email,
    required String role,
  }) => client.rpc(
    'set_member_role_by_email',
    params: {'p_org': organizationId, 'p_email': email, 'p_role': role},
  );

  /// Links a `staff` row to an existing account by email, so that account's
  /// sign-in resolves to this staff row (staff_today_page.dart, and the
  /// staff-self clause of change_appointment_status()) — see
  /// supabase/migrations/0031_link_staff_to_login.sql.
  Future<void> linkToUserByEmail({
    required String staffId,
    required String email,
  }) => client.rpc(
    'link_staff_to_user_by_email',
    params: {'p_staff': staffId, 'p_email': email},
  );

  /// Which services this staff member is qualified to perform
  /// (`staff_services` — booking rejects any service/staff pair not
  /// listed here, see 0002/0007/0009/0011/0013's STAFF_CANNOT_PERFORM_SERVICE
  /// check).
  Future<List<String>> listAssignedServiceIds(String staffId) async {
    final rows = await client
        .from('staff_services')
        .select('service_id')
        .eq('staff_id', staffId);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((r) => r['service_id'] as String).toList();
  }

  /// Replaces this staff member's full set of qualified services.
  Future<void> setAssignedServices({
    required String staffId,
    required List<String> serviceIds,
  }) async {
    await client.from('staff_services').delete().eq('staff_id', staffId);
    if (serviceIds.isNotEmpty) {
      await client
          .from('staff_services')
          .insert(
            serviceIds
                .map((id) => {'staff_id': staffId, 'service_id': id})
                .toList(),
          );
    }
  }

  /// service_id -> qualified staff_ids, for every active staff member in
  /// [organizationId] — lets booking_page.dart filter the staff dropdown to
  /// only staff who can perform the selected service (readable by anon too,
  /// via staff_services_public_select in 0012_public_storefront_access.sql,
  /// so this also covers the public booking flow).
  Future<Map<String, List<String>>> serviceIdsToStaffIds(
    String organizationId,
  ) async {
    final staffIds = (await listIdNameActive(
      organizationId,
    )).map((r) => r['id'] as String).toList();
    if (staffIds.isEmpty) return {};
    final rows = await client
        .from('staff_services')
        .select('staff_id,service_id')
        .inFilter('staff_id', staffIds);
    final map = <String, List<String>>{};
    for (final r in List<Map<String, dynamic>>.from(rows)) {
      map
          .putIfAbsent(r['service_id'] as String, () => [])
          .add(r['staff_id'] as String);
    }
    return map;
  }
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);
