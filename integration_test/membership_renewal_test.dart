import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

/// Acceptance criteria for renew_membership()
/// (supabase/migrations/0034_renew_membership.sql): renewing extends the
/// *same* customer_memberships row in place — carrying over any remaining
/// time when renewed early, and starting a fresh term from today (not from
/// the already-passed old end date) when renewed after expiry. It must not
/// behave like purchase_membership() and create a second row.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'renewing an active membership adds the new term on top of the time '
    'remaining, in place — no second row is created',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final customer = await createTestCustomer(org.orgId, name: 'Renewal Customer');

      final membership = await client
          .from('memberships')
          .insert({
            'organization_id': org.orgId,
            'name': 'Monthly Plan',
            'price_minor': 3000,
            'discount_percent': 10,
            'duration_days': 30,
          })
          .select()
          .single();

      final customerMembershipId = await client.rpc(
        'purchase_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer': customer,
          'p_membership': membership['id'],
          'p_method': 'cash',
        },
      );

      final before = await client
          .from('customer_memberships')
          .select('ends_at,status')
          .eq('id', customerMembershipId)
          .single();
      final originalEndsAt = DateTime.parse(before['ends_at'] as String);
      expect(
        before['status'],
        'active',
        reason: 'purchase_membership() should have created an active row.',
      );

      await client.rpc(
        'renew_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer_membership': customerMembershipId,
          'p_method': 'cash',
        },
      );

      final rows = await client
          .from('customer_memberships')
          .select('id,ends_at,status')
          .eq('customer_id', customer);
      expect(
        rows.length,
        1,
        reason: 'renew_membership() must extend the existing row, not '
            'insert a second customer_memberships row the way a fresh '
            'sale would.',
      );

      final after = rows.first;
      final newEndsAt = DateTime.parse(after['ends_at'] as String);
      final expectedEndsAt = originalEndsAt.add(const Duration(days: 30));
      expect(
        newEndsAt.difference(expectedEndsAt).inSeconds.abs() < 5,
        true,
        reason: 'Renewing an active membership should add a full 30-day '
            'term on top of the original ends_at ($originalEndsAt), '
            'landing at $expectedEndsAt — got $newEndsAt instead, which '
            'means remaining time was not carried over correctly.',
      );
      expect(after['status'], 'active');

      // Idempotency: replaying the *original* purchase idempotency key
      // must still just return the same row without renewing again —
      // renew_membership() only touches its own idempotency key, so this
      // also confirms the two operations don't interfere with each other.
      final renewedAgainId = await client.rpc(
        'purchase_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer': customer,
          'p_membership': membership['id'],
          'p_method': 'cash',
        },
      );
      expect(
        renewedAgainId,
        isNot(customerMembershipId),
        reason: 'A second purchase_membership() call (new idempotency '
            'key) is a genuinely new sale and must create its own row, '
            'confirming renew_membership() did not somehow merge into '
            "purchase_membership()'s behavior.",
      );
    },
  );

  test(
    'renewing an expired membership starts the new term from today, not '
    'from the old (already-passed) end date',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final customer = await createTestCustomer(org.orgId, name: 'Lapsed Customer');

      final membership = await client
          .from('memberships')
          .insert({
            'organization_id': org.orgId,
            'name': 'Monthly Plan',
            'price_minor': 3000,
            'discount_percent': 10,
            'duration_days': 30,
          })
          .select()
          .single();

      final customerMembershipId = await client.rpc(
        'purchase_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer': customer,
          'p_membership': membership['id'],
          'p_method': 'cash',
        },
      );

      // Backdate ends_at to simulate a membership that lapsed 10 days ago.
      // Allowed the same way locations_page.dart's direct updates are: any
      // org member can update a row scoped to their own org (0005_rls.sql).
      final pastEndsAt = DateTime.now().toUtc().subtract(const Duration(days: 10));
      await client
          .from('customer_memberships')
          .update({'ends_at': pastEndsAt.toIso8601String()})
          .eq('id', customerMembershipId);

      final beforeRenew = DateTime.now().toUtc();

      await client.rpc(
        'renew_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer_membership': customerMembershipId,
          'p_method': 'cash',
        },
      );

      final after = await client
          .from('customer_memberships')
          .select('ends_at,status')
          .eq('id', customerMembershipId)
          .single();
      final newEndsAt = DateTime.parse(after['ends_at'] as String);
      final expectedFromToday = beforeRenew.add(const Duration(days: 30));
      final expectedFromOldEnds = pastEndsAt.add(const Duration(days: 30));

      expect(
        newEndsAt.difference(expectedFromToday).inSeconds.abs() < 10,
        true,
        reason: 'An expired membership should renew from today ($beforeRenew '
            '+ 30 days = $expectedFromToday), not from the old, '
            'already-passed ends_at ($pastEndsAt + 30 days = '
            '$expectedFromOldEnds) — got $newEndsAt.',
      );
      expect(after['status'], 'active');
    },
  );

  test(
    'a cancelled membership cannot be renewed',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final customer = await createTestCustomer(org.orgId, name: 'Cancelled Customer');

      final membership = await client
          .from('memberships')
          .insert({
            'organization_id': org.orgId,
            'name': 'Monthly Plan',
            'price_minor': 3000,
            'discount_percent': 10,
            'duration_days': 30,
          })
          .select()
          .single();

      final customerMembershipId = await client.rpc(
        'purchase_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer': customer,
          'p_membership': membership['id'],
          'p_method': 'cash',
        },
      );

      await client
          .from('customer_memberships')
          .update({'status': 'cancelled'})
          .eq('id', customerMembershipId);

      await expectLater(
        client.rpc(
          'renew_membership',
          params: {
            'p_idempotency': const Uuid().v4(),
            'p_customer_membership': customerMembershipId,
            'p_method': 'cash',
          },
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('MEMBERSHIP_CANCELLED'),
            'throws MEMBERSHIP_CANCELLED',
          ),
        ),
        reason: 'A cancelled membership must not be silently reactivated '
            'by renew — that would need a fresh purchase_membership() '
            'sale instead.',
      );
    },
  );
}
