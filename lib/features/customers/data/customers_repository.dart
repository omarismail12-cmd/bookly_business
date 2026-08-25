import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/local/local_store.dart';
import '../../../core/local/local_store_provider.dart';
import '../domain/customer.dart';

/// Wraps every Supabase call for `customers` and the customer-360 data
/// customer_detail_dialog.dart / crm_page.dart need: loyalty points,
/// purchased packages/memberships, the active offers catalog for selling,
/// and campaigns. Presentation code must go through this instead of calling
/// `Supabase.instance.client` directly, so RLS-respecting query shape lives
/// in one place per feature.
///
/// Creating a customer stays outside this repository — customers_page.dart
/// and crm_page.dart write through [SyncService] instead (local-first,
/// offline-safe), same as before this refactor.
class CustomersRepository {
  final SupabaseClient client;
  final LocalStore localStore;
  CustomersRepository(this.client, this.localStore);

  /// [offlineFallback] mirrors customers_page.dart's pre-refactor behavior
  /// of falling back to the local mirror WorkspaceMirror keeps warm for
  /// `customers` (spec slide 9); crm_page.dart never had that fallback, so
  /// it calls this with `offlineFallback: false` to keep behaving exactly
  /// as it did before — a live-fetch failure still surfaces as an error.
  Future<List<Customer>> list({
    required String organizationId,
    String? search,
    int page = 0,
    int pageSize = 25,
    bool paginate = true,
    int limit = 500,
    bool offlineFallback = false,
  }) async {
    final searchText = search?.trim() ?? '';
    try {
      var query = client
          .from('customers')
          .select()
          .eq('organization_id', organizationId)
          .isFilter('deleted_at', null);
      if (searchText.isNotEmpty) {
        query = query.ilike('name', '%$searchText%');
      }
      final ordered = query.order('name');
      final rows = paginate
          ? await ordered.range(page * pageSize, page * pageSize + pageSize - 1)
          : await ordered.limit(limit);
      return List<Map<String, dynamic>>.from(rows).map(Customer.fromRow).toList();
    } catch (_) {
      if (!offlineFallback) rethrow;
      final cached = await localStore.list('customers');
      var filtered = cached
          .where(
            (r) =>
                r['organization_id'] == organizationId &&
                r['deleted_at'] == null,
          )
          .toList();
      if (searchText.isNotEmpty) {
        filtered = filtered
            .where(
              (r) => (r['name'] as String? ?? '').toLowerCase().contains(
                searchText.toLowerCase(),
              ),
            )
            .toList();
      }
      filtered.sort(
        (a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
      );
      final pageRows = paginate
          ? filtered.skip(page * pageSize).take(pageSize).toList()
          : filtered.take(limit).toList();
      return pageRows.map(Customer.fromRow).toList();
    }
  }

  Future<String> orgCurrency(String organizationId) async {
    final row = await client
        .from('organizations')
        .select('currency')
        .eq('id', organizationId)
        .maybeSingle();
    return (row?['currency'] as String?) ?? 'USD';
  }

  Future<int> loyaltyPoints(String customerId) async {
    final row = await client
        .from('loyalty_accounts')
        .select('points')
        .eq('customer_id', customerId)
        .maybeSingle();
    return ((row as Map?)?['points'] as num?)?.toInt() ?? 0;
  }

  /// Batch points lookup for crm_page.dart's list, keyed by customer id.
  Future<Map<String, int>> loyaltyPointsForCustomers(
    List<String> customerIds,
  ) async {
    if (customerIds.isEmpty) return {};
    final rows = await client
        .from('loyalty_accounts')
        .select('customer_id,points')
        .inFilter('customer_id', customerIds);
    final result = <String, int>{};
    for (final row in rows) {
      result[row['customer_id'] as String] =
          (row['points'] as num?)?.toInt() ?? 0;
    }
    return result;
  }

  Future<void> redeemLoyaltyPoints({
    required String customerId,
    required int points,
  }) => client.rpc(
    'redeem_loyalty_points',
    params: {'p_customer': customerId, 'p_points': points},
  );

  Future<List<Map<String, dynamic>>> customerPackages(String customerId) async {
    final rows = await client
        .from('customer_packages')
        .select('id,remaining_uses,expires_at,status,packages(name)')
        .eq('customer_id', customerId)
        .order('purchased_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> redeemPackageUse(String customerPackageId) => client.rpc(
    'redeem_package_use',
    params: {'p_customer_package': customerPackageId},
  );

  Future<List<Map<String, dynamic>>> activePackagesCatalog(
    String organizationId,
  ) async {
    final rows = await client
        .from('packages')
        .select('id,name,price_minor')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> sellPackage({
    required String idempotencyKey,
    required String customerId,
    required String packageId,
    required String method,
  }) => client.rpc(
    'sell_package',
    params: {
      'p_idempotency': idempotencyKey,
      'p_customer': customerId,
      'p_package': packageId,
      'p_method': method,
    },
  );

  Future<List<Map<String, dynamic>>> customerMemberships(
    String customerId,
  ) async {
    final rows = await client
        .from('customer_memberships')
        .select('id,membership_id,status,starts_at,ends_at,memberships(name)')
        .eq('customer_id', customerId)
        .order('starts_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> activeMembershipsCatalog(
    String organizationId,
  ) async {
    final rows = await client
        .from('memberships')
        .select('id,name,price_minor')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> purchaseMembership({
    required String idempotencyKey,
    required String customerId,
    required String membershipId,
    required String method,
  }) => client.rpc(
    'purchase_membership',
    params: {
      'p_idempotency': idempotencyKey,
      'p_customer': customerId,
      'p_membership': membershipId,
      'p_method': method,
    },
  );

  /// Extends an existing customer_memberships row in place — see
  /// supabase/migrations/0034_renew_membership.sql. A genuinely new sale
  /// goes through [purchaseMembership] instead.
  Future<void> renewMembership({
    required String idempotencyKey,
    required String customerMembershipId,
    required String method,
  }) => client.rpc(
    'renew_membership',
    params: {
      'p_idempotency': idempotencyKey,
      'p_customer_membership': customerMembershipId,
      'p_method': method,
    },
  );

  Future<void> cancelMembership(String customerMembershipId) => client
      .from('customer_memberships')
      .update({'status': 'cancelled'})
      .eq('id', customerMembershipId);

  Future<List<Map<String, dynamic>>> campaigns(String organizationId) async {
    final rows = await client
        .from('campaigns')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createCampaignDraft({
    required String organizationId,
    required String name,
    required String segment,
    required String channel,
    required String message,
  }) => client.from('campaigns').insert({
    'organization_id': organizationId,
    'name': name,
    'segment': segment,
    'channel': channel,
    'message': message,
    'status': 'draft',
  });

  Future<int> sendCampaign(String campaignId) async {
    final result = await client.rpc(
      'send_campaign',
      params: {'p_campaign': campaignId},
    );
    return (result as num).toInt();
  }
}

final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(
    ref.watch(supabaseProvider),
    ref.watch(localStoreProvider),
  ),
);
