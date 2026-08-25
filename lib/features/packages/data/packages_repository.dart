import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';
import '../domain/package_offer.dart';

/// Wraps every Supabase call for the offers catalog: `packages`,
/// `memberships` and `coupons`. Presentation code must go through this
/// instead of calling `Supabase.instance.client` directly. Selling a
/// package/membership to a customer or redeeming a coupon against a
/// specific booking goes through their own RPCs elsewhere (customers /
/// payments features) — this repository only owns the catalog itself.
///
/// `packages`/`memberships`/`coupons` are kept warm by [WorkspaceMirror] for
/// offline reading, same as `services`/`staff` — the `list*` methods fall
/// back to that cache when the live fetch fails. The cache has no join, so
/// a cache-fallback [PackageOffer] has no `serviceName`.
class PackagesRepository {
  final SupabaseClient client;
  final LocalStore localStore;
  PackagesRepository(this.client, this.localStore);

  Future<List<PackageOffer>> listPackages(String organizationId) async {
    try {
      final rows = await client
          .from('packages')
          .select('*,services(name)')
          .eq('organization_id', organizationId)
          .order('name');
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(PackageOffer.fromRow).toList();
    } catch (_) {
      final cached = await _cachedRows('packages', organizationId);
      cached.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return cached.map(PackageOffer.fromRow).toList();
    }
  }

  Future<List<Map<String, dynamic>>> _cachedRows(
    String table,
    String organizationId,
  ) async {
    final rows = await localStore.list(table);
    return rows.where((r) => r['organization_id'] == organizationId).toList();
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

  Future<void> updatePackage({
    required String id,
    required String name,
    String? serviceId,
    required int priceMinor,
    required int totalUses,
    int? expiresDays,
  }) => client.from('packages').update({
    'name': name,
    'service_id': serviceId,
    'price_minor': priceMinor,
    'total_uses': totalUses,
    'expires_days': expiresDays,
  }).eq('id', id);

  Future<List<Membership>> listMemberships(String organizationId) async {
    try {
      final rows = await client
          .from('memberships')
          .select()
          .eq('organization_id', organizationId)
          .order('name');
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(Membership.fromRow).toList();
    } catch (_) {
      final cached = await _cachedRows('memberships', organizationId);
      cached.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      return cached.map(Membership.fromRow).toList();
    }
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

  Future<void> updateMembership({
    required String id,
    required String name,
    required int priceMinor,
    required num discountPercent,
    required int durationDays,
  }) => client.from('memberships').update({
    'name': name,
    'price_minor': priceMinor,
    'discount_percent': discountPercent,
    'duration_days': durationDays,
  }).eq('id', id);

  Future<List<Coupon>> listCoupons(String organizationId) async {
    try {
      final rows = await client
          .from('coupons')
          .select()
          .eq('organization_id', organizationId)
          .order('code');
      return List<Map<String, dynamic>>.from(rows).map(Coupon.fromRow).toList();
    } catch (_) {
      final cached = await _cachedRows('coupons', organizationId);
      cached.sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
      return cached.map(Coupon.fromRow).toList();
    }
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

  Future<void> updateCoupon({
    required String id,
    required String code,
    num? discountPercent,
    int? usageLimit,
  }) => client.from('coupons').update({
    'code': code,
    'discount_percent': discountPercent,
    'usage_limit': usageLimit,
  }).eq('id', id);

  /// Toggles `active` on a catalog row. [table] must be one of 'packages',
  /// 'memberships', 'coupons' — the three tables this repository owns.
  Future<void> setActive(String table, String id, bool active) =>
      client.from(table).update({'active': active}).eq('id', id);
}

final packagesRepositoryProvider = Provider<PackagesRepository>(
  (ref) => PackagesRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);
