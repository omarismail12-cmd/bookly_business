import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'test_helpers.dart';

/// Acceptance criterion: a business owner can look up an available slot and
/// book it end-to-end through the same RPCs the app's BookingPage and
/// PaymentsPage call — get_available_slots -> create_booking ->
/// record_payment — with the result actually landing in Postgres, not just
/// returning without error.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('booking flow happy path: slot lookup -> booking -> payment', (
    tester,
  ) async {
    await ensureSupabaseInitialized();
    final client = Supabase.instance.client;

    await signUpTestUser();
    final org = await createTestOrgWithService();
    final customerId = await createTestCustomer(org.orgId);

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
    expect(
      slotList,
      isNotEmpty,
      reason: 'A freshly created staff member with open working hours '
          'should have at least one available slot.',
    );
    final startsAt = slotList.first['starts_at'] as String;

    final appointmentId = await client.rpc(
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
    expect(appointmentId, isA<String>());

    final appointment = await client
        .from('appointments')
        .select()
        .eq('id', appointmentId as String)
        .single();
    expect(appointment['status'], 'confirmed');
    expect(appointment['customer_id'], customerId);
    expect(appointment['staff_id'], org.staffId);
    expect(appointment['organization_id'], org.orgId);

    final paymentId = await client.rpc(
      'record_payment',
      params: {
        'p_idempotency': const Uuid().v4(),
        'p_appointment': appointmentId,
        'p_amount': 5000,
        'p_method': 'cash',
        'p_type': 'payment',
      },
    );
    expect(paymentId, isA<String>());

    final payment = await client
        .from('payments')
        .select()
        .eq('id', paymentId as String)
        .single();
    expect(payment['amount_minor'], 5000);
    expect(payment['appointment_id'], appointmentId);
  });
}
