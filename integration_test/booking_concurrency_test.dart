import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

typedef _Attempt = ({bool success, String? appointmentId, Object? error});

Future<_Attempt> _attemptBooking({
  required String orgId,
  required String customerId,
  required String staffId,
  required String serviceId,
  required String startsAt,
}) async {
  try {
    final id = await Supabase.instance.client.rpc(
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
/// constraint `appointments_staff_no_overlap` (supabase/migrations/0001) is
/// the actual guarantee under test — get_available_slots only prevents the
/// *common* case client-side, the database constraint is what makes it safe
/// under real concurrency.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'two simultaneous create_booking calls for the same slot: exactly one succeeds',
    (tester) async {
      await ensureSupabaseInitialized();
      final client = Supabase.instance.client;

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
          orgId: org.orgId,
          customerId: customerA,
          staffId: org.staffId,
          serviceId: org.serviceId,
          startsAt: startsAt,
        ),
        _attemptBooking(
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
      expect(
        failed.single.error.toString(),
        contains('SLOT_ALREADY_BOOKED'),
        reason:
            'The loser should fail with SLOT_ALREADY_BOOKED, raised by '
            'create_booking() when the exclusion constraint fires.',
      );

      // And the database agrees: only one confirmed appointment for this
      // staff member at this slot, not zero and not two.
      final rows = await client
          .from('appointments')
          .select()
          .eq('staff_id', org.staffId)
          .eq('starts_at', startsAt)
          .inFilter('status', ['pending', 'confirmed', 'checked_in', 'in_service']);
      expect(rows.length, 1);
    },
  );
}
