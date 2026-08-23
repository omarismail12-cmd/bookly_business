/// A bookable service offered by an organization.
///
/// Mirrors `public.services` exactly (see supabase/migrations/0001_foundation.sql).
class Service {
  final String id;
  final String organizationId;
  final String? categoryId;
  final String name;
  final String? description;
  final int durationMin;
  final int bufferMin;
  final int priceMinor;
  final int depositRequiredMinor;
  final int cancellationWindowMin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int version;

  const Service({
    required this.id,
    required this.organizationId,
    this.categoryId,
    required this.name,
    this.description,
    required this.durationMin,
    required this.bufferMin,
    required this.priceMinor,
    required this.depositRequiredMinor,
    required this.cancellationWindowMin,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    required this.version,
  });

  factory Service.fromRow(Map<String, dynamic> row) => Service(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    categoryId: row['category_id'] as String?,
    name: row['name'] as String,
    description: row['description'] as String?,
    durationMin: row['duration_min'] as int,
    bufferMin: row['buffer_min'] as int,
    priceMinor: (row['price_minor'] as num).toInt(),
    depositRequiredMinor: (row['deposit_required_minor'] as num).toInt(),
    cancellationWindowMin: row['cancellation_window_min'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    createdBy: row['created_by'] as String?,
    updatedBy: row['updated_by'] as String?,
    deletedAt: row['deleted_at'] != null
        ? DateTime.parse(row['deleted_at'] as String)
        : null,
    version: (row['version'] as num).toInt(),
  );
}
