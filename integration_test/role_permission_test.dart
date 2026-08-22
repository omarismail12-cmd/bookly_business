import 'package:test/test.dart';

import 'test_helpers.dart';

/// Acceptance criterion: tenant isolation and role permissions are enforced
/// by the database (RLS + RPC checks), independently of what the Flutter
/// UI shows — per README's "Business logic and authorization live in the
/// database" design. Two things under test:
///  1. A member of org B cannot read org A's data (RLS filters rows away
///     rather than raising, so the assertion is "empty result", not "throw").
///  2. A `staff`-role member cannot perform an owner-only action
///     (set_member_role_by_email) or write to organizations (owner-only).
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'staff cannot see another org\'s data or perform owner-only actions',
    () async {
      final client = ensureSupabaseInitialized();

      // Org A: owner + one customer, used as the "other org" that must stay
      // invisible to org B's staff member.
      await signUpTestUser();
      final orgA = await createTestOrgWithService();
      await createTestCustomer(orgA.orgId, name: 'Org A Secret Customer');
      await client.auth.signOut();

      // Org B: owner creates the org, then demotes a second user to staff.
      final ownerB = await signUpTestUser();
      final orgB = await createTestOrgWithService();
      final staffUser = await signUpTestUser();
      await signIn(ownerB.email, ownerB.password);
      await client.rpc(
        'set_member_role_by_email',
        params: {
          'p_org': orgB.orgId,
          'p_email': staffUser.email,
          'p_role': 'staff',
        },
      );
      await client.auth.signOut();

      // Now act as org B's staff member.
      await signIn(staffUser.email, staffUser.password);

      // 1) Cross-org read is invisible, not just "forbidden with an error"
      // — RLS filters the row out entirely.
      final crossOrgCustomers = await client
          .from('customers')
          .select()
          .eq('organization_id', orgA.orgId);
      expect(
        crossOrgCustomers,
        isEmpty,
        reason: "Org B's staff member must not see org A's customers.",
      );

      // Sanity check: the same staff member *can* see their own org's data,
      // proving the empty result above is RLS filtering by org, not a
      // broken query.
      final ownOrgStaff = await client
          .from('staff')
          .select()
          .eq('organization_id', orgB.orgId);
      expect(ownOrgStaff, isNotEmpty);

      // 2) Owner-only RPC rejects a staff caller.
      final other = await signUpTestUser();
      await signIn(staffUser.email, staffUser.password);
      await expectLater(
        client.rpc(
          'set_member_role_by_email',
          params: {
            'p_org': orgB.orgId,
            'p_email': other.email,
            'p_role': 'manager',
          },
        ),
        throwsA(anything),
        reason:
            'set_member_role_by_email() requires the owner role '
            '(supabase/migrations/0007) — a staff caller must be rejected.',
      );

      // 3) Owner-only screen data: updating the organization row is blocked
      // by RLS for non-owners. Postgrest applies RLS as a row filter on
      // UPDATE too, so a blocked write returns zero affected rows rather
      // than throwing.
      final updated = await client
          .from('organizations')
          .update({'name': 'Hijacked By Staff'})
          .eq('id', orgB.orgId)
          .select();
      expect(
        updated,
        isEmpty,
        reason:
            'organizations_update RLS policy restricts updates to the '
            'owner role; a staff caller\'s update must affect zero rows.',
      );
    },
  );
}
