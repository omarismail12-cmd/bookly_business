import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

/// Acceptance criterion (reminder targeting): the notification jobs created
/// for an appointment must address only that appointment's own customer —
/// never another customer in the same organization.
/// queue_appointment_notifications() (supabase/migrations/0014, called
/// automatically inside create_booking()'s transaction) inserts a
/// confirmation + two reminder rows into notification_jobs, each carrying
/// recipient_customer_id = the appointment's own customer_id. This test
/// books for two different customers and checks their notification_jobs
/// never cross.
///
/// Note: the current implementation only ever targets the customer
/// (recipient_customer_id) — it does not also create a staff-targeted row
/// (recipient_user_id stays null for every job it inserts), so this test
/// covers customer targeting only, matching what queue_appointment_
/// notifications() actually does.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'notification jobs for an appointment target only that appointment\'s '
    'own customer, not other customers in the same org',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final customerA = await createTestCustomer(org.orgId, name: 'Notify A');
      final customerB = await createTestCustomer(org.orgId, name: 'Notify B');

      Future<String> book(String customerId, int dayOffset) async {
        final date = testBookingDate().add(Duration(days: dayOffset));
        final slots = await client.rpc(
          'get_available_slots',
          params: {
            'p_staff': org.staffId,
            'p_service': org.serviceId,
            'p_date': date.toIso8601String().substring(0, 10),
          },
        );
        final startsAt =
            List<Map<String, dynamic>>.from(slots).first['starts_at'] as String;
        final id = await client.rpc(
          'create_booking',
          params: {
            'p_operation_id': const Uuid().v4(),
            'p_organization': org.orgId,
            'p_customer': customerId,
            'p_staff': org.staffId,
            'p_service': org.serviceId,
            'p_starts_at': startsAt,
            'p_source': 'reception',
          },
        );
        return id as String;
      }

      final appointmentA = await book(customerA, 0);
      final appointmentB = await book(customerB, 1);

      final jobsForA = await client
          .from('notification_jobs')
          .select('recipient_customer_id,appointment_id,kind')
          .eq('appointment_id', appointmentA);
      final jobsForB = await client
          .from('notification_jobs')
          .select('recipient_customer_id,appointment_id,kind')
          .eq('appointment_id', appointmentB);

      // Both bookings should have queued the same three job kinds
      // (confirmation, reminder_24h, reminder_2h).
      expect(jobsForA.length, 3);
      expect(jobsForB.length, 3);

      for (final job in jobsForA) {
        expect(
          job['recipient_customer_id'],
          customerA,
          reason: "Appointment A's ${job['kind']} job must target customer "
              'A, not any other customer.',
        );
      }
      for (final job in jobsForB) {
        expect(
          job['recipient_customer_id'],
          customerB,
          reason: "Appointment B's ${job['kind']} job must target customer "
              'B, not any other customer.',
        );
      }

      // And directly: querying by recipient never returns the other
      // customer's appointment.
      final jobsAddressedToA = await client
          .from('notification_jobs')
          .select('appointment_id')
          .eq('recipient_customer_id', customerA);
      expect(
        jobsAddressedToA.every((j) => j['appointment_id'] == appointmentA),
        isTrue,
        reason: 'Every job addressed to customer A must belong to '
            "customer A's own appointment.",
      );
    },
  );
}
