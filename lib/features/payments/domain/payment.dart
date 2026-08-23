/// A payment/deposit/refund record.
///
/// Core columns mirror `public.payments` exactly
/// (supabase/migrations/0002_booking_operations.sql); `customerName` comes
/// from the `*,appointments(customers(name))` join the repository performs
/// for the list view.
class Payment {
  final String id;
  final String organizationId;
  final String? appointmentId;
  final int amountMinor;
  final String method;
  final String type;
  final String status;
  final String? providerReference;
  final String? idempotencyKey;
  final DateTime createdAt;
  final String? createdBy;
  final String? customerName;

  const Payment({
    required this.id,
    required this.organizationId,
    this.appointmentId,
    required this.amountMinor,
    required this.method,
    required this.type,
    required this.status,
    this.providerReference,
    this.idempotencyKey,
    required this.createdAt,
    this.createdBy,
    this.customerName,
  });

  factory Payment.fromRow(Map<String, dynamic> row) => Payment(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    appointmentId: row['appointment_id'] as String?,
    amountMinor: (row['amount_minor'] as num).toInt(),
    method: row['method'] as String,
    type: row['type'] as String,
    status: row['status'] as String,
    providerReference: row['provider_reference'] as String?,
    idempotencyKey: row['idempotency_key'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    createdBy: row['created_by'] as String?,
    customerName:
        ((row['appointments'] as Map?)?['customers'] as Map?)?['name']
            as String?,
  );
}
