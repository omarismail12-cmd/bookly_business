import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';
import '../domain/staff_member.dart';

/// Wraps every Supabase call for the `staff` table and staff role
/// assignment. Presentation code must go through this instead of calling
/// `Supabase.instance.client` directly (mirrors OrganizationRepository's
/// style in lib/features/organisations/data/organization_repository.dart).
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
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);
