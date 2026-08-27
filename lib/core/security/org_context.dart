import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationMembership {
  final String organizationId;
  final String organizationName;
  final String slug;
  final String timezone;
  final String currency;
  final String role;
  const OrganizationMembership({
    required this.organizationId,
    required this.organizationName,
    required this.slug,
    required this.timezone,
    required this.currency,
    required this.role,
  });
}

/// Single source of truth for "what is the current user's active business
/// membership" — used both by [activeMembershipProvider] (Riverpod call
/// sites) and directly by widgets that aren't ConsumerWidgets (e.g.
/// BusinessShell), so the query only lives in one place.
Future<OrganizationMembership?> fetchActiveMembership() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final rows = await Supabase.instance.client
      .from('organization_members')
      .select(
        'organization_id,role,organizations(id,name,slug,timezone,currency,status)',
      )
      .eq('user_id', uid)
      .eq('status', 'active')
      // Deterministic pick for accounts with multiple active memberships —
      // oldest first, matching seed_demo_data_for_current_user()'s own
      // `order by created_at limit 1` convention for "the" org. Without an
      // explicit order, Postgres/PostgREST give no ordering guarantee, so
      // which org this resolved to was previously undefined per call.
      .order('created_at')
      .limit(1);
  if (rows.isEmpty) return null;
  final row = Map<String, dynamic>.from(rows.first);
  final org = Map<String, dynamic>.from(row['organizations'] as Map);
  if ((org['status'] ?? 'active') != 'active') return null;
  return OrganizationMembership(
    organizationId: row['organization_id'] as String,
    organizationName: org['name']?.toString() ?? 'Bookly Business',
    slug: org['slug']?.toString() ?? '',
    timezone: org['timezone']?.toString() ?? 'UTC',
    currency: org['currency']?.toString() ?? 'USD',
    role: row['role']?.toString() ?? 'staff',
  );
}

final activeMembershipProvider = FutureProvider<OrganizationMembership?>(
  (ref) => fetchActiveMembership(),
);

final activeOrganizationProvider = FutureProvider<String?>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.organizationId;
});

final activeRoleProvider = FutureProvider<String?>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.role;
});

final activeCurrencyProvider = FutureProvider<String>((ref) async {
  return (await ref.watch(activeMembershipProvider.future))?.currency ??
      'USD';
});
