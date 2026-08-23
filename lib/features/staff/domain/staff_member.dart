/// A staff member of an organization.
///
/// Mirrors `public.staff` exactly (see supabase/migrations/0001_foundation.sql).
class StaffMember {
  final String id;
  final String organizationId;
  final String? profileId;
  final String displayName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int version;

  const StaffMember({
    required this.id,
    required this.organizationId,
    this.profileId,
    required this.displayName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    required this.version,
  });

  factory StaffMember.fromRow(Map<String, dynamic> row) => StaffMember(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    profileId: row['profile_id'] as String?,
    displayName: (row['display_name'] as String?) ?? 'Unnamed',
    status: (row['status'] as String?) ?? 'active',
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
