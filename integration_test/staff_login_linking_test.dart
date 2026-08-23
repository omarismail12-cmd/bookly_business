import 'package:test/test.dart';

import 'test_helpers.dart';

/// Phase 7 acceptance criteria: `staff.profile_id` — the column
/// staff_today_page.dart and change_appointment_status()'s staff-self clause
/// both depend on to resolve "which staff row is this signed-in user" — had
/// no way to be set except a manual database edit. This exercises the new
/// `link_staff_to_user_by_email` RPC (0031_link_staff_to_login.sql) that
/// StaffPage's new "Link login" action calls.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'owner can link a staff row to an existing member account by email, '
    'and the linked account can then see itself in the staff table',
    () async {
      final client = ensureSupabaseInitialized();

      final owner = await signUpTestUser();
      final org = await createTestOrgWithService();

      final staffUser = await signUpTestUser();
      await signIn(owner.email, owner.password);

      // Not a member of the org yet — must be rejected, not silently linked
      // to an account with no real relationship to the business.
      await expectLater(
        client.rpc(
          'link_staff_to_user_by_email',
          params: {'p_staff': org.staffId, 'p_email': staffUser.email},
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('USER_NOT_A_MEMBER'),
          ),
        ),
      );

      // set_member_role_by_email() (0007) auto-creates its OWN staff row for
      // a fresh 'staff' role assignment — this is the realistic scenario
      // link_staff_to_user_by_email() has to handle: the account is already
      // claimed by that auto-created row, and the owner wants it moved onto
      // the pre-existing row (org.staffId) they actually schedule against.
      await client.rpc(
        'set_member_role_by_email',
        params: {
          'p_org': org.orgId,
          'p_email': staffUser.email,
          'p_role': 'staff',
        },
      );
      final autoCreated = await client
          .from('staff')
          .select('id')
          .eq('organization_id', org.orgId)
          .eq('profile_id', staffUser.userId)
          .single();
      final autoCreatedId = autoCreated['id'] as String;
      expect(
        autoCreatedId,
        isNot(org.staffId),
        reason: 'Sanity check on the test setup itself: role assignment '
            'must have auto-created a different row than the one under '
            'test, or the rest of this test is not exercising anything.',
      );

      await client.rpc(
        'link_staff_to_user_by_email',
        params: {'p_staff': org.staffId, 'p_email': staffUser.email},
      );

      final linked = await client
          .from('staff')
          .select('profile_id')
          .eq('id', org.staffId)
          .single();
      expect(linked['profile_id'], staffUser.userId);

      // The auto-created duplicate must have been unlinked, not left
      // pointing at the same account — staff_org_profile_unique only allows
      // one staff row per (org, profile_id).
      final autoCreatedAfter = await client
          .from('staff')
          .select('profile_id')
          .eq('id', autoCreatedId)
          .single();
      expect(autoCreatedAfter['profile_id'], isNull);

      final allLinkedToStaffUser = await client
          .from('staff')
          .select('id')
          .eq('organization_id', org.orgId)
          .eq('profile_id', staffUser.userId);
      expect(
        allLinkedToStaffUser,
        hasLength(1),
        reason: 'Exactly one staff row in this org may point at this '
            'account at a time.',
      );

      // The linked account itself should now resolve to this staff row —
      // exactly what staff_today_page.dart relies on.
      await signIn(staffUser.email, staffUser.password);
      final selfLookup = await client
          .from('staff')
          .select('id')
          .eq('organization_id', org.orgId)
          .eq('profile_id', staffUser.userId)
          .maybeSingle();
      expect(selfLookup?['id'], org.staffId);
    },
  );

  test(
    'a non-owner cannot link a staff row to their own account',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();

      final intruder = await signUpTestUser();

      await expectLater(
        client.rpc(
          'link_staff_to_user_by_email',
          params: {'p_staff': org.staffId, 'p_email': intruder.email},
        ),
        throwsA(
          predicate((e) => e.toString().contains('FORBIDDEN')),
        ),
      );
    },
  );
}
