/// A prepaid package of service uses.
///
/// Mirrors `public.packages` exactly (supabase/migrations/0003_crm_loyalty.sql).
/// `serviceName` comes from the `*,services(name)` join the repository
/// performs for the list view.
class PackageOffer {
  final String id;
  final String organizationId;
  final String name;
  final int priceMinor;
  final String? serviceId;
  final int totalUses;
  final int? expiresDays;
  final DateTime createdAt;
  final bool active;
  final String? serviceName;

  const PackageOffer({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.priceMinor,
    this.serviceId,
    required this.totalUses,
    this.expiresDays,
    required this.createdAt,
    required this.active,
    this.serviceName,
  });

  factory PackageOffer.fromRow(Map<String, dynamic> row) => PackageOffer(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    name: row['name'] as String,
    priceMinor: (row['price_minor'] as num).toInt(),
    serviceId: row['service_id'] as String?,
    totalUses: row['total_uses'] as int,
    expiresDays: row['expires_days'] as int?,
    createdAt: DateTime.parse(row['created_at'] as String),
    active: row['active'] as bool,
    serviceName: (row['services'] as Map?)?['name'] as String?,
  );
}

/// A recurring discount membership.
///
/// Mirrors `public.memberships` exactly.
class Membership {
  final String id;
  final String organizationId;
  final String name;
  final int priceMinor;
  final num discountPercent;
  final int durationDays;
  final bool active;

  const Membership({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.priceMinor,
    required this.discountPercent,
    required this.durationDays,
    required this.active,
  });

  factory Membership.fromRow(Map<String, dynamic> row) => Membership(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    name: row['name'] as String,
    priceMinor: (row['price_minor'] as num).toInt(),
    discountPercent: row['discount_percent'] as num,
    durationDays: row['duration_days'] as int,
    active: row['active'] as bool,
  );
}

/// A discount coupon.
///
/// Mirrors `public.coupons` exactly.
class Coupon {
  final String id;
  final String organizationId;
  final String code;
  final num? discountPercent;
  final int? discountMinor;
  final DateTime? expiresAt;
  final int? usageLimit;
  final int usageCount;
  final bool active;

  const Coupon({
    required this.id,
    required this.organizationId,
    required this.code,
    this.discountPercent,
    this.discountMinor,
    this.expiresAt,
    this.usageLimit,
    required this.usageCount,
    required this.active,
  });

  factory Coupon.fromRow(Map<String, dynamic> row) => Coupon(
    id: row['id'] as String,
    organizationId: row['organization_id'] as String,
    code: row['code'] as String,
    discountPercent: row['discount_percent'] as num?,
    discountMinor: (row['discount_minor'] as num?)?.toInt(),
    expiresAt: row['expires_at'] != null
        ? DateTime.parse(row['expires_at'] as String)
        : null,
    usageLimit: row['usage_limit'] as int?,
    usageCount: row['usage_count'] as int,
    active: row['active'] as bool,
  );
}
