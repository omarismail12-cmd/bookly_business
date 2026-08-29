import 'package:supabase/supabase.dart';

/// Pure-Dart core of org_context.dart's membership lookup — no
/// `package:flutter`, `flutter_riverpod`, or `supabase_flutter` import
/// anywhere in this file's dependency graph, deliberately. org_context.dart
/// wraps this for the real app (defaulting [fetchActiveMembership]'s client
/// to `Supabase.instance.client` and exposing it as Riverpod providers);
/// integration_test/dashboard_org_isolation_test.dart imports this file
/// directly instead, because it needs to run under plain `dart test`
/// against a real Supabase project, and anything that pulls in
/// `package:flutter` fails to even compile there (no `dart:ui` outside a
/// real Flutter engine — see test_helpers.dart's doc comment for the full
/// explanation). Keep it that way: don't add a supabase_flutter or
/// flutter_riverpod import to this file.
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

/// Single source of truth for "what is [client]'s current user's active
/// business membership". [client] is required (not defaulted to a global
/// singleton) so this stays usable from a plain Dart test with a plain
/// `package:supabase` client — see the class doc above. Named distinctly
/// from org_context.dart's zero-arg `fetchActiveMembership()` wrapper
/// (which calls this with `Supabase.instance.client`) since Dart can't
/// overload top-level functions by arity.
Future<OrganizationMembership?> fetchActiveMembershipFor(
  SupabaseClient client,
) async {
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  final rows = await client
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
