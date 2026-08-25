import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/formatters/currency.dart';
import '../../payments/data/payments_repository.dart';

/// Customer 360 view: profile + notes, loyalty points, purchased packages
/// and memberships, and coupon redemption. Selling/redeeming actions are
/// gated to owner/manager/receptionist to match the payments-taking role
/// set used elsewhere (Permission.takePayments); everyone who can see the
/// Customers page can view this dialog and edit notes.
class CustomerDetailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> customer;
  final String role;

  const CustomerDetailDialog({
    super.key,
    required this.customer,
    required this.role,
  });

  @override
  ConsumerState<CustomerDetailDialog> createState() =>
      _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends ConsumerState<CustomerDetailDialog> {
  bool loading = true;
  int points = 0;
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> memberships = [];
  List<Map<String, dynamic>> catalogPackages = [];
  List<Map<String, dynamic>> catalogMemberships = [];
  late final TextEditingController notes;
  final coupon = TextEditingController();
  bool savingNotes = false;
  String currency = 'USD';

  bool get canTransact =>
      widget.role == 'owner' ||
      widget.role == 'manager' ||
      widget.role == 'receptionist';

  String get customerId => widget.customer['id'] as String;
  String get organizationId => widget.customer['organization_id'] as String;

  @override
  void initState() {
    super.initState();
    notes = TextEditingController(
      text: (widget.customer['private_notes'] as String?) ?? '',
    );
    Future.microtask(load);
  }

  @override
  void dispose() {
    notes.dispose();
    coupon.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final c = Supabase.instance.client;
    final org = await c
        .from('organizations')
        .select('currency')
        .eq('id', organizationId)
        .maybeSingle();
    final loyalty = await c
        .from('loyalty_accounts')
        .select('points')
        .eq('customer_id', customerId)
        .maybeSingle();
    final pkgs = await c
        .from('customer_packages')
        .select('id,remaining_uses,expires_at,status,packages(name)')
        .eq('customer_id', customerId)
        .order('purchased_at', ascending: false);
    final mems = await c
        .from('customer_memberships')
        .select('id,membership_id,status,starts_at,ends_at,memberships(name)')
        .eq('customer_id', customerId)
        .order('starts_at', ascending: false);
    final catalogPkgs = await c
        .from('packages')
        .select('id,name,price_minor')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('name');
    final catalogMems = await c
        .from('memberships')
        .select('id,name,price_minor')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('name');
    if (!mounted) return;
    setState(() {
      currency = (org?['currency'] as String?) ?? currency;
      points = ((loyalty as Map?)?['points'] as num?)?.toInt() ?? 0;
      packages = List<Map<String, dynamic>>.from(pkgs);
      memberships = List<Map<String, dynamic>>.from(mems);
      catalogPackages = List<Map<String, dynamic>>.from(catalogPkgs);
      catalogMemberships = List<Map<String, dynamic>>.from(catalogMems);
      loading = false;
    });
  }

  /// Local-first, conflict-checked edit (spec slide 9): queues through
  /// SyncService instead of writing straight to Supabase, so editing notes
  /// works offline. [baseVersion] is the customer's `version` column as
  /// last loaded — if it's moved server-side by drain time, SyncService
  /// parks the edit as a conflict instead of overwriting silently (see
  /// SyncService._applyVersionedUpdate). A still-optimistic customer row
  /// (just added, not yet synced) has no `version` yet, so the check is
  /// simply skipped for that one edit — nothing to conflict against.
  Future<void> saveNotes() async {
    setState(() => savingNotes = true);
    try {
      final operationId = const Uuid().v4();
      final baseVersion = (widget.customer['version'] as num?)?.toInt();
      final sync = ref.read(syncServiceProvider);
      await sync.enqueue(
        SyncOperation(
          operationId: operationId,
          entity: 'customers',
          entityId: customerId,
          operation: 'update_customer_notes',
          payload: {
            'private_notes': notes.text.trim(),
            '_base_version': ?baseVersion,
          },
        ),
      );
      await sync.drain();
      if (!mounted) return;
      final conflicted = (await sync.conflicts()).any(
        (o) => o.operationId == operationId,
      );
      final stillPending = (await sync.store.pending()).any(
        (o) => o.operationId == operationId,
      );
      if (!mounted) return;
      final message = conflicted
          ? 'These notes were changed elsewhere — resolve the conflict from the sync banner.'
          : stillPending
          ? "Offline — notes will sync when you're back online."
          : 'Notes saved.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save notes: $e')));
      }
    } finally {
      if (mounted) setState(() => savingNotes = false);
    }
  }

  Future<void> redeemPoints() async {
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Redeem points'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Points (balance: $points)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (int.tryParse(amount.text.trim()) ?? 0) > 0,
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'redeem_loyalty_points',
        params: {
          'p_customer': customerId,
          'p_points': int.parse(amount.text.trim()),
        },
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not redeem points: $e')));
      }
    }
  }

  Future<void> redeemPackageUse(Map<String, dynamic> customerPackage) async {
    final name = (customerPackage['packages'] as Map?)?['name'] ?? 'Package';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Use one visit'),
        content: Text(
          'Use one visit from "$name"? '
          '${customerPackage['remaining_uses']} remaining.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'redeem_package_use',
        params: {'p_customer_package': customerPackage['id']},
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not use package visit: $e')),
        );
      }
    }
  }

  Future<void> sellPackage() async {
    if (catalogPackages.isEmpty) return;
    String? packageId = catalogPackages.first['id'] as String;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Sell package'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: packageId,
                decoration: const InputDecoration(labelText: 'Package'),
                items: catalogPackages
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(
                          '${p['name']} • ${formatMinor((p['price_minor'] as num).toInt(), currency: currency)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => packageId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                onChanged: (v) => setLocal(() => method = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sell'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || packageId == null) return;
    try {
      await Supabase.instance.client.rpc(
        'sell_package',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer': customerId,
          'p_package': packageId,
          'p_method': method,
        },
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not sell package: $e')));
      }
    }
  }

  Future<void> sellMembership() async {
    if (catalogMemberships.isEmpty) return;
    String? membershipId = catalogMemberships.first['id'] as String;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Sell membership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: membershipId,
                decoration: const InputDecoration(labelText: 'Membership'),
                items: catalogMemberships
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text(
                          '${m['name']} • ${formatMinor((m['price_minor'] as num).toInt(), currency: currency)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => membershipId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                onChanged: (v) => setLocal(() => method = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sell'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || membershipId == null) return;
    try {
      await Supabase.instance.client.rpc(
        'purchase_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer': customerId,
          'p_membership': membershipId,
          'p_method': method,
        },
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sell membership: $e')),
        );
      }
    }
  }

  Map<String, dynamic>? _catalogMembership(String? membershipId) {
    if (membershipId == null) return null;
    for (final m in catalogMemberships) {
      if (m['id'] == membershipId) return m;
    }
    return null;
  }

  Future<void> cancelMembership(Map<String, dynamic> row) async {
    final name = (row['memberships'] as Map?)?['name'] ?? 'Membership';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel membership?'),
        content: Text(
          'Cancel "$name"? The customer loses its discount immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel membership'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('customer_memberships')
          .update({'status': 'cancelled'})
          .eq('id', row['id']);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel membership: $e')),
        );
      }
    }
  }

  Future<void> renewMembership(Map<String, dynamic> row) async {
    final catalog = _catalogMembership(row['membership_id'] as String?);
    if (catalog == null) return;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Renew ${catalog['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Price: ${formatMinor((catalog['price_minor'] as num).toInt(), currency: currency)}',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                onChanged: (v) => setLocal(() => method = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      // renew_membership() extends this same row's ends_at in place
      // (carrying over remaining time) — a genuinely new sale would go
      // through sellMembership()/purchase_membership() above instead.
      await Supabase.instance.client.rpc(
        'renew_membership',
        params: {
          'p_idempotency': const Uuid().v4(),
          'p_customer_membership': row['id'],
          'p_method': method,
        },
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not renew membership: $e')),
        );
      }
    }
  }

  Future<void> redeemCoupon() async {
    if (coupon.text.trim().isEmpty) return;
    try {
      final data = await ref.read(paymentsRepositoryProvider).redeemCoupon(
        organizationId: organizationId,
        code: coupon.text.trim(),
        customerId: customerId,
      );
      final pct = data['discount_percent'];
      final minor = data['discount_minor'];
      final discount = pct != null
          ? '$pct% off'
          : minor != null
          ? '${formatMinor((minor as num).toInt(), currency: currency)} off'
          : 'applied';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Coupon redeemed: $discount')));
      }
      coupon.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not redeem coupon: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['name'] ?? '',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text('${c['phone'] ?? ''} • ${c['email'] ?? ''}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _stat(
                            'Total spent',
                            formatMinor(
                              (c['total_spent_minor'] as num? ?? 0).toInt(),
                              currency: currency,
                            ),
                          ),
                          _stat('No-shows', '${c['no_show_count'] ?? 0}'),
                          _stat(
                            'Last visit',
                            c['last_visit_at'] == null
                                ? 'Never'
                                : DateTime.parse(
                                    c['last_visit_at'],
                                  ).toLocal().toString().substring(0, 10),
                          ),
                          _stat('Loyalty points', '$points'),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Private notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Preferences, allergies, reminders…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        // AlignmentDirectional so this mirrors correctly in
                        // Arabic (RTL) instead of always pinning to the
                        // geometric right.
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: savingNotes ? null : saveNotes,
                          child: const Text('Save notes'),
                        ),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Loyalty',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canTransact && points > 0)
                            TextButton(
                              onPressed: redeemPoints,
                              child: const Text('Redeem points'),
                            ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Packages',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canTransact && catalogPackages.isNotEmpty)
                            TextButton(
                              onPressed: sellPackage,
                              child: const Text('Sell package'),
                            ),
                        ],
                      ),
                      if (packages.isEmpty) const Text('No packages owned.'),
                      ...packages.map(
                        (p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            (p['packages'] as Map?)?['name'] ?? 'Package',
                          ),
                          subtitle: Text(
                            '${p['remaining_uses']} uses left • ${p['status']}'
                            '${p['expires_at'] != null ? ' • expires ${DateTime.parse(p['expires_at']).toLocal().toString().substring(0, 10)}' : ''}',
                          ),
                          trailing:
                              canTransact &&
                                  p['status'] == 'active' &&
                                  (p['remaining_uses'] as num? ?? 0) > 0
                              ? TextButton(
                                  onPressed: () => redeemPackageUse(p),
                                  child: const Text('Use 1'),
                                )
                              : null,
                        ),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Memberships',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canTransact && catalogMemberships.isNotEmpty)
                            TextButton(
                              onPressed: sellMembership,
                              child: const Text('Sell membership'),
                            ),
                        ],
                      ),
                      if (memberships.isEmpty)
                        const Text('No memberships owned.'),
                      ...memberships.map((m) {
                        // This schema has no distinct "expired" status —
                        // status is only ever 'active' or 'cancelled'
                        // (renew_membership() refuses to touch a
                        // cancelled row); an active-but-past-ends_at row
                        // is still 'active'. So Renew (early or lapsed)
                        // is offered on any non-cancelled row with a
                        // matching active catalog entry, alongside
                        // Cancel.
                        final cancelled = m['status'] == 'cancelled';
                        final renewable =
                            !cancelled && _catalogMembership(m['membership_id'] as String?) != null;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            (m['memberships'] as Map?)?['name'] ?? 'Membership',
                          ),
                          subtitle: Text(
                            '${m['status']} • until ${DateTime.parse(m['ends_at']).toLocal().toString().substring(0, 10)}',
                          ),
                          trailing: !canTransact || cancelled
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (renewable)
                                      TextButton(
                                        onPressed: () => renewMembership(m),
                                        child: const Text('Renew'),
                                      ),
                                    TextButton(
                                      onPressed: () => cancelMembership(m),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                        );
                      }),
                      if (canTransact) ...[
                        const Divider(height: 32),
                        Text(
                          'Coupon',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: coupon,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Coupon code',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: redeemCoupon,
                              child: const Text('Redeem'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}
