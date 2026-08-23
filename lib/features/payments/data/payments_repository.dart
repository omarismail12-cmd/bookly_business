import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../domain/payment.dart';

const _pageSize = 20;

/// Wraps every Supabase call for `payments`: paginated reads, the
/// `record_payment`/`redeem_coupon` RPC transactions, and the supporting
/// picker queries the "record payment" dialog needs (bookable appointments,
/// active membership discount). Payments must never be inserted/updated
/// directly — always through `record_payment`, which is what makes the
/// idempotency key actually prevent a duplicate charge on retry
/// (supabase/migrations/0002_booking_operations.sql).
class PaymentsRepository {
  final SupabaseClient client;
  PaymentsRepository(this.client);

  Future<List<Payment>> listPage(String organizationId, {int page = 0}) async {
    final rows = await client
        .from('payments')
        .select('*,appointments(customers(name))')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .range(page * _pageSize, page * _pageSize + _pageSize - 1);
    return List<Map<String, dynamic>>.from(rows).map(Payment.fromRow).toList();
  }

  /// Recent bookable appointments for the "record payment" dialog's picker.
  Future<List<Map<String, dynamic>>> listBookableAppointments(
    String organizationId,
  ) async {
    final rows = await client
        .from('appointments')
        .select('id,starts_at,customer_id,customers(name)')
        .eq('organization_id', organizationId)
        .inFilter('status', [
          'confirmed',
          'checked_in',
          'in_service',
          'completed',
        ])
        .order('starts_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Active membership discount percent for a customer, or null if they
  /// have none.
  Future<num?> activeMembershipDiscount(String customerId) async {
    final row = await client
        .from('customer_memberships')
        .select('memberships(discount_percent)')
        .eq('customer_id', customerId)
        .eq('status', 'active')
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('ends_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return (row?['memberships'] as Map?)?['discount_percent'] as num?;
  }

  Future<Map<String, dynamic>> redeemCoupon({
    required String organizationId,
    required String code,
    required String? customerId,
    required String appointmentId,
  }) async {
    final result = await client.rpc(
      'redeem_coupon',
      params: {
        'p_org': organizationId,
        'p_code': code,
        'p_customer': customerId,
        'p_appointment': appointmentId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> recordPayment({
    required String idempotencyKey,
    required String appointmentId,
    required int amountMinor,
    required String method,
    required String type,
  }) => client.rpc(
    'record_payment',
    params: {
      'p_idempotency': idempotencyKey,
      'p_appointment': appointmentId,
      'p_amount': amountMinor,
      'p_method': method,
      'p_type': type,
    },
  );
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(supabaseProvider)),
);

const paymentsPageSize = _pageSize;
