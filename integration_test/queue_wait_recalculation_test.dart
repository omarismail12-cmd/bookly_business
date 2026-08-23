import 'package:test/test.dart';

import 'test_helpers.dart';

/// Acceptance criterion (queue wait recalculation): completing (or
/// cancelling) a queue entry must reduce the estimated wait for every entry
/// behind it — recalculate_queue_wait() sums the durations of only the
/// still-waiting entries ahead of each one (supabase/migrations/0010), so
/// removing an entry from that set should shorten everyone else's wait by
/// exactly its service duration, not leave stale numbers behind.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'completing a queue entry reduces the estimated wait for entries behind it',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final durationMin =
          (await client
                  .from('services')
                  .select('duration_min')
                  .eq('id', org.serviceId)
                  .single())['duration_min']
              as int;

      final customerA = await createTestCustomer(org.orgId, name: 'Queue A');
      final customerB = await createTestCustomer(org.orgId, name: 'Queue B');
      final customerC = await createTestCustomer(org.orgId, name: 'Queue C');

      Future<String> addWalkIn(String customerId) async {
        final id = await client.rpc(
          'add_walk_in',
          params: {'p_customer': customerId, 'p_service': org.serviceId},
        );
        return id as String;
      }

      final entryA = await addWalkIn(customerA);
      final entryB = await addWalkIn(customerB);
      final entryC = await addWalkIn(customerC);

      Future<int> waitFor(String entryId) async {
        final row = await client
            .from('queue_entries')
            .select('estimated_wait_min')
            .eq('id', entryId)
            .single();
        return row['estimated_wait_min'] as int;
      }

      // Before anyone is removed: A is first (no wait), B waits behind A's
      // full service duration, C waits behind both A and B.
      expect(await waitFor(entryA), 0);
      expect(await waitFor(entryB), durationMin);
      expect(await waitFor(entryC), durationMin * 2);

      // Complete A — recalculate_queue_wait() excludes anything not
      // waiting/called/in_service from the sum, so B and C should each
      // shorten by exactly A's duration.
      await client.rpc(
        'change_queue_status',
        params: {'p_queue': entryA, 'p_status': 'completed'},
      );

      expect(
        await waitFor(entryB),
        0,
        reason: 'B was directly behind A; with A completed, B should now '
            'be first in line with no wait.',
      );
      expect(
        await waitFor(entryC),
        durationMin,
        reason: 'C was behind both A and B; with A completed, C should '
            "only wait behind B's duration now.",
      );
    },
  );
}
