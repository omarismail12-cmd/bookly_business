/// A physical location of an organization.
///
/// Mirrors `public.locations` exactly (see supabase/migrations/0001_foundation.sql).
class Location {
  final String id;
  final String organizationId;
  final String name;
  final String? address;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int version;

  const Location({
    required this.id,
    required this.organizationId,
    required this.name,
    this.address,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    required this.version,
  });

  factory Location.fromRow(Map<String, dynamic> row) => Location(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    name: (row['name'] as String?) ?? '',
    address: row['address'] as String?,
    timezone: (row['timezone'] as String?) ?? 'UTC',
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
