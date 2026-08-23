/// A walk-in queue entry, with the joined display fields the queue UI needs.
///
/// Core columns mirror `public.queue_entries` exactly
/// (supabase/migrations/0002_booking_operations.sql); `customerName`,
/// `serviceName` and `staffName` come from the
/// `*,customers(name),services(name),staff(display_name)` join the
/// repository performs for the list view.
class QueueEntry {
  final String id;
  final String organizationId;
  final String customerId;
  final String serviceId;
  final String? staffId;
  final int queueNumber;
  final String status;
  final DateTime checkedInAt;
  final int estimatedWaitMin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerName;
  final String? serviceName;
  final String? staffName;

  const QueueEntry({
    required this.id,
    required this.organizationId,
    required this.customerId,
    required this.serviceId,
    this.staffId,
    required this.queueNumber,
    required this.status,
    required this.checkedInAt,
    required this.estimatedWaitMin,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.serviceName,
    this.staffName,
  });

  factory QueueEntry.fromRow(Map<String, dynamic> row) => QueueEntry(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    customerId: row['customer_id'] as String,
    serviceId: row['service_id'] as String,
    staffId: row['staff_id'] as String?,
    queueNumber: row['queue_number'] as int,
    status: row['status'] as String,
    checkedInAt: DateTime.parse(row['checked_in_at'] as String),
    estimatedWaitMin: row['estimated_wait_min'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    customerName: (row['customers'] as Map?)?['name'] as String?,
    serviceName: (row['services'] as Map?)?['name'] as String?,
    staffName: (row['staff'] as Map?)?['display_name'] as String?,
  );
}
