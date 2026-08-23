import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

/// Phase 6 acceptance criterion: booking-confirmed and rescheduled events
/// must notify the assigned staff member too, not just the customer —
/// queue_appointment_notifications()/queue_reschedule_notifications()
/// (0030_staff_notification_targeting.sql) insert 'confirmation_staff' and
/// 'reschedule'/'reschedule_staff' jobs targeting the staff member's own
/// account (recipient_user_id = staff.profile_id), alongside the existing
/// customer-targeted jobs. Also checks that rescheduling refreshes the
/// existing reminder_24h job's scheduled_for against the NEW start time,
/// instead of leaving it stale against the original booking time.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'booking confirmation and reschedule notify the assigned staff member, '
    'not just the customer',
    () async {
      final client = ensureSupabaseInitialized();

      final owner = await signUpTestUser();
      final org = await createTestOrgWithService();

      // Link a real user to the test org's staff row, so there's an
      // account for the notification's recipient_user_id to target —
      // createTestOrgWithService() leaves staff.profile_id null (an
      // unclaimed staff row), which the new logic deliberately skips.
      final staffUser = await signUpTestUser();
      await signIn(owner.email, owner.password);
      await client
          .from('staff')
          .update({'profile_id': staffUser.userId})
          .eq('id', org.staffId);

      final customer = await createTestCustomer(
        org.orgId,
        name: 'Notify Staff Test',
      );

      final date = testBookingDate();
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

      final appointmentId = await client.rpc(
        'create_booking',
        params: {
          'p_operation_id': const Uuid().v4(),
          'p_organization': org.orgId,
          'p_customer': customer,
          'p_staff': org.staffId,
          'p_service': org.serviceId,
          'p_starts_at': startsAt,
          'p_source': 'reception',
        },
      );

      final confirmationStaffJobs = await client
          .from('notification_jobs')
          .select('recipient_customer_id,recipient_user_id')
          .eq('appointment_id', appointmentId)
          .eq('kind', 'confirmation_staff');
      expect(
        confirmationStaffJobs,
        hasLength(1),
        reason: 'Booking creation must queue a confirmation_staff job for '
            'the assigned staff member.',
      );
      expect(confirmationStaffJobs.first['recipient_user_id'], staffUser.userId);
      expect(
        confirmationStaffJobs.first['recipient_customer_id'],
        isNull,
        reason: 'The staff job must target the staff account, not the '
            'customer.',
      );

      // Reschedule: should queue a fresh reschedule/reschedule_staff pair,
      // and refresh reminder_24h's scheduled_for to the new time.
      final newStartsAt = DateTime.parse(
        startsAt,
      ).add(const Duration(hours: 1));
      await client.rpc(
        'reschedule_appointment',
        params: {
          'p_appointment': appointmentId,
          'p_new_start': newStartsAt.toIso8601String(),
        },
      );

      final rescheduleStaffJobs = await client
          .from('notification_jobs')
          .select('recipient_user_id')
          .eq('appointment_id', appointmentId)
          .eq('kind', 'reschedule_staff');
      expect(rescheduleStaffJobs, hasLength(1));
      expect(rescheduleStaffJobs.first['recipient_user_id'], staffUser.userId);

      final rescheduleCustomerJobs = await client
          .from('notification_jobs')
          .select('recipient_customer_id')
          .eq('appointment_id', appointmentId)
          .eq('kind', 'reschedule');
      expect(rescheduleCustomerJobs, hasLength(1));
      expect(rescheduleCustomerJobs.first['recipient_customer_id'], customer);

      // The pre-existing reminder job must have been refreshed against the
      // NEW start time, not left stale from the original booking — the bug
      // reschedule_appointment() had before this migration (it never called
      // any notification function at all).
      final reminder24 = await client
          .from('notification_jobs')
          .select('scheduled_for')
          .eq('appointment_id', appointmentId)
          .eq('kind', 'reminder_24h')
          .single();
      final expected24h = newStartsAt.toUtc().subtract(
        const Duration(hours: 24),
      );
      final actual24h = DateTime.parse(reminder24['scheduled_for'] as String);
      expect(
        actual24h.difference(expected24h).inMinutes.abs() < 2,
        isTrue,
        reason: 'reminder_24h should be rescheduled against the NEW start '
            'time after reschedule_appointment(), not left pointing at the '
            'original booking time.',
      );
    },
  );
}
