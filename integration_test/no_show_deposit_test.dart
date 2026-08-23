import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

/// Acceptance criterion (no-show risk scoring): marking an appointment
/// no_show must increment the customer's risk score, and once that score
/// crosses the threshold effective_deposit_minor() checks (>= 3, see
/// supabase/migrations/0011_no_show_deposit_policy.sql), a later booking for
/// that same customer must require a deposit even for a service that has no
/// deposit configured at all — 50% of the service price, per that
/// migration's documented policy.
///
/// Run with `dart test integration_test` (not `flutter test` — see
/// test_helpers.dart's doc comment for why).
void main() {
  test(
    'no_show marks increment no_show_count, and crossing the threshold '
    'forces a deposit on a service with none configured',
    () async {
      final client = ensureSupabaseInitialized();

      await signUpTestUser();
      final org = await createTestOrgWithService();
      final customer = await createTestCustomer(org.orgId, name: 'Risky Customer');

      // createTestOrgWithService's service is created with no
      // deposit_required_minor at all, so it defaults to 0 (no deposit) —
      // see 0001_foundation.sql. Confirm that starting point before relying
      // on it below.
      final service = await client
          .from('services')
          .select('deposit_required_minor,price_minor')
          .eq('id', org.serviceId)
          .single();
      expect(
        service['deposit_required_minor'],
        0,
        reason: 'This test needs a service with no deposit configured — '
            'that\'s what makes the forced deposit below attributable to '
            'the no-show policy, not the service itself.',
      );
      final priceMinor = service['price_minor'] as int;

      // Book and no-show three separate appointments for the same customer.
      // Each needs its own slot — three different days keeps them clear of
      // each other regardless of the service's duration.
      for (var i = 0; i < 3; i++) {
        final date = testBookingDate().add(Duration(days: i));
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

        await client.rpc(
          'change_appointment_status',
          params: {'p_appointment': appointmentId, 'p_status': 'no_show'},
        );
      }

      final customerRow = await client
          .from('customers')
          .select('no_show_count')
          .eq('id', customer)
          .single();
      expect(
        customerRow['no_show_count'],
        3,
        reason: 'Three no_show marks should have incremented no_show_count '
            'by exactly one each.',
      );

      // A fourth booking, for the same no-deposit service, should now carry
      // a forced deposit: ceil(price * 0.5), per effective_deposit_minor().
      final finalDate = testBookingDate().add(const Duration(days: 3));
      final finalSlots = await client.rpc(
        'get_available_slots',
        params: {
          'p_staff': org.staffId,
          'p_service': org.serviceId,
          'p_date': finalDate.toIso8601String().substring(0, 10),
        },
      );
      final finalStartsAt = List<Map<String, dynamic>>.from(
        finalSlots,
      ).first['starts_at'] as String;

      final riskyAppointmentId = await client.rpc(
        'create_booking',
        params: {
          'p_operation_id': const Uuid().v4(),
          'p_organization': org.orgId,
          'p_customer': customer,
          'p_staff': org.staffId,
          'p_service': org.serviceId,
          'p_starts_at': finalStartsAt,
          'p_source': 'reception',
        },
      );

      final riskyAppointment = await client
          .from('appointments')
          .select('deposit_required_minor')
          .eq('id', riskyAppointmentId)
          .single();
      final expectedDeposit = (priceMinor * 0.5).ceil();
      expect(
        riskyAppointment['deposit_required_minor'],
        expectedDeposit,
        reason: 'A customer with no_show_count >= 3 must be required to '
            'pay a 50% deposit even on a service with no deposit '
            'configured — this booking must not be silently deposit-free.',
      );
    },
  );
}
