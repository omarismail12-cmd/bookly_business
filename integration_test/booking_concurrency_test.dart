import 'package:supabase/supabase.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

typedef _Attempt = ({bool success, String? appointmentId, Object? error});

Future<_Attempt> _attemptBooking({
  required SupabaseClient client,
  required String orgId,
  required String customerId,
  required String staffId,
  required String serviceId,
  required String startsAt,
}) async {
  try {
    final id = await client.rpc(
      'create_booking',
      params: {
        'p_operation_id': const Uuid().v4(),
        'p_organization': orgId,
        'p_customer': customerId,
        'p_staff': staffId,
        'p_service': serviceId,
        'p_starts_at': startsAt,
        'p_source': 'reception',
      },
    );
    return (success: true, appointmentId: id as String, error: null);
  } catch (e) {
    return (success: false, appointmentId: null, error: e);
  }
}

/// Acceptance criterion (double-booking): two clients racing to book the
/// same staff member's same time slot must not both succeed. The exclusion
/// constraint `appointments_staff_no_overlap` (supabase/migrations/0001,
/// hardened in 0008 to be buffer-aware) is the actual guarantee under test —
/// get_available_slots only prevents the *common* case client-side, the
/// database constraint is what makes it safe under real concurrency.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'two simultaneous create_booking calls for the same slot: exactly one succeeds',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final customerA = await createTestCustomer(org.orgId, name: 'Racer A');
      final customerB = await createTestCustomer(org.orgId, name: 'Racer B');

      final date = testBookingDate();
      final slots = await client.rpc(
        'get_available_slots',
        params: {
          'p_staff': org.staffId,
          'p_service': org.serviceId,
          'p_date': date.toIso8601String().substring(0, 10),
        },
      );
      final slotList = List<Map<String, dynamic>>.from(slots);
      expect(slotList, isNotEmpty);
      final startsAt = slotList.first['starts_at'] as String;

      // Both requests are issued back-to-back with no await between them,
      // so they race at the database rather than serializing client-side.
      final results = await Future.wait([
        _attemptBooking(
          client: client,
          orgId: org.orgId,
          customerId: customerA,
          staffId: org.staffId,
          serviceId: org.serviceId,
          startsAt: startsAt,
        ),
        _attemptBooking(
          client: client,
          orgId: org.orgId,
          customerId: customerB,
          staffId: org.staffId,
          serviceId: org.serviceId,
          startsAt: startsAt,
        ),
      ]);

      final succeeded = results.where((r) => r.success).toList();
      final failed = results.where((r) => !r.success).toList();

      expect(
        succeeded.length,
        1,
        reason:
            'Exactly one of the two racing bookings should succeed; got '
            '${succeeded.length} successes and ${failed.length} failures.',
      );
      // The loser fails one of two ways depending on exact timing, both
      // correct: if its own get_available_slots() pre-check runs after the
      // winner's row is already visible, create_booking() rejects it with
      // SLOT_NOT_AVAILABLE before even attempting the insert; if the
      // pre-checks for both race ahead of either insert, the loser reaches
      // the insert and the appointments_staff_no_overlap exclusion
      // constraint raises SLOT_ALREADY_BOOKED instead. Either way, exactly
      // one booking exists — verified by the two asserts above/below.
      expect(
        failed.single.error.toString(),
        anyOf(contains('SLOT_ALREADY_BOOKED'), contains('SLOT_NOT_AVAILABLE')),
        reason:
            'The loser should be rejected by either the exclusion '
            'constraint (SLOT_ALREADY_BOOKED) or the pre-check '
            '(SLOT_NOT_AVAILABLE) — not silently succeed.',
      );

      // And the database agrees: only one confirmed appointment for this
      // staff member at this slot, not zero and not two.
      final rows = await client
          .from('appointments')
          .select()
          .eq('staff_id', org.staffId)
          .eq('starts_at', startsAt)
          .inFilter('status', [
            'pending',
            'confirmed',
            'checked_in',
            'in_service',
          ]);
      expect(rows.length, 1);
    },
  );
}
