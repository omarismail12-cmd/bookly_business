/// A customer of an organization.
///
/// Mirrors `public.customers` exactly (see supabase/migrations/0001_foundation.sql),
/// plus [pending] — a UI-only flag (never persisted) that customers_page.dart
/// and crm_page.dart set on an optimistic row shown before SyncService
/// confirms an offline-queued create has actually synced.
class Customer {
  final String id;
  final String organizationId;
  final String name;
  final String? phone;
  final String? email;
  final DateTime? birthday;
  final String? privateNotes;
  final int noShowCount;
  final int totalSpentMinor;
  final DateTime? lastVisitAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int? version;
  final bool pending;

  const Customer({
    required this.id,
    required this.organizationId,
    required this.name,
    this.phone,
    this.email,
    this.birthday,
    this.privateNotes,
    this.noShowCount = 0,
    this.totalSpentMinor = 0,
    this.lastVisitAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    this.version,
    this.pending = false,
  });

  factory Customer.fromRow(Map<String, dynamic> row) => Customer(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    name: (row['name'] as String?) ?? '',
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    birthday: row['birthday'] != null
        ? DateTime.parse(row['birthday'] as String)
        : null,
    privateNotes: row['private_notes'] as String?,
    noShowCount: (row['no_show_count'] as num?)?.toInt() ?? 0,
    totalSpentMinor: (row['total_spent_minor'] as num?)?.toInt() ?? 0,
    lastVisitAt: row['last_visit_at'] != null
        ? DateTime.parse(row['last_visit_at'] as String)
        : null,
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String)
        : null,
    updatedAt: row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : null,
    createdBy: row['created_by'] as String?,
    updatedBy: row['updated_by'] as String?,
    deletedAt: row['deleted_at'] != null
        ? DateTime.parse(row['deleted_at'] as String)
        : null,
    version: (row['version'] as num?)?.toInt(),
  );
}
