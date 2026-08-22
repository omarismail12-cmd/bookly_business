import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationMembership {
  final String organizationId;
  final String organizationName;
  final String timezone;
  final String role;
  const OrganizationMembership({
    required this.organizationId,
    required this.organizationName,
    required this.timezone,
    required this.role,
  });
}

final activeMembershipProvider = FutureProvider<OrganizationMembership?>((
  ref,
) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final rows = await Supabase.instance.client
      .from('organization_members')
      .select('organization_id,role,organizations(id,name,timezone,status)')
      .eq('user_id', uid)
      .eq('status', 'active')
      .limit(1);
  if (rows.isEmpty) return null;
  final row = Map<String, dynamic>.from(rows.first);
  final org = Map<String, dynamic>.from(row['organizations'] as Map);
  if ((org['status'] ?? 'active') != 'active') return null;
  return OrganizationMembership(
    organizationId: row['organization_id'] as String,
    organizationName: org['name']?.toString() ?? 'Bookly Business',
    timezone: org['timezone']?.toString() ?? 'UTC',
    role: row['role']?.toString() ?? 'staff',
  );
});

final activeOrganizationProvider = FutureProvider<String?>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.organizationId;
});

final activeRoleProvider = FutureProvider<String?>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.role;
});
