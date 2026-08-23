import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../domain/package_offer.dart';

/// Wraps every Supabase call for the offers catalog: `packages`,
/// `memberships` and `coupons`. Presentation code must go through this
/// instead of calling `Supabase.instance.client` directly (mirrors
/// OrganizationRepository's style in
/// lib/features/organisations/data/organization_repository.dart). Selling a
/// package/membership to a customer or redeeming a coupon against a
/// specific booking goes through their own RPCs elsewhere (customers /
/// payments features) — this repository only owns the catalog itself.
class PackagesRepository {
  final SupabaseClient client;
  PackagesRepository(this.client);

  Future<List<PackageOffer>> listPackages(String organizationId) async {
    final rows = await client
        .from('packages')
        .select('*,services(name)')
        .eq('organization_id', organizationId)
        .order('name');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(PackageOffer.fromRow).toList();
  }

  Future<void> createPackage({
    required String organizationId,
    required String name,
    String? serviceId,
    required int priceMinor,
    required int totalUses,
    int? expiresDays,
  }) => client.from('packages').insert({
    'organization_id': organizationId,
    'name': name,
    'service_id': serviceId,
    'price_minor': priceMinor,
    'total_uses': totalUses,
    'expires_days': expiresDays,
  });

  Future<List<Membership>> listMemberships(String organizationId) async {
    final rows = await client
        .from('memberships')
        .select()
        .eq('organization_id', organizationId)
        .order('name');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(Membership.fromRow).toList();
  }

  Future<void> createMembership({
    required String organizationId,
    required String name,
    required int priceMinor,
    required num discountPercent,
    required int durationDays,
  }) => client.from('memberships').insert({
    'organization_id': organizationId,
    'name': name,
    'price_minor': priceMinor,
    'discount_percent': discountPercent,
    'duration_days': durationDays,
  });

  Future<List<Coupon>> listCoupons(String organizationId) async {
    final rows = await client
        .from('coupons')
        .select()
        .eq('organization_id', organizationId)
        .order('code');
    return List<Map<String, dynamic>>.from(rows).map(Coupon.fromRow).toList();
  }

  Future<void> createCoupon({
    required String organizationId,
    required String code,
    num? discountPercent,
    int? usageLimit,
  }) => client.from('coupons').insert({
    'organization_id': organizationId,
    'code': code,
    'discount_percent': discountPercent,
    'usage_limit': usageLimit,
  });
}

final packagesRepositoryProvider = Provider<PackagesRepository>(
  (ref) => PackagesRepository(ref.watch(supabaseProvider)),
);
