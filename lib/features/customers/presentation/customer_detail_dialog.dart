import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/formatters/currency.dart';

/// Customer 360 view: profile + notes, loyalty points, purchased packages
/// and memberships, and coupon redemption. Selling/redeeming actions are
/// gated to owner/manager/receptionist to match the payments-taking role
/// set used elsewhere (Permission.takePayments); everyone who can see the
/// Customers page can view this dialog and edit notes.
class CustomerDetailDialog extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String role;

  const CustomerDetailDialog({
    super.key,
    required this.customer,
    required this.role,
  });

  @override
  State<CustomerDetailDialog> createState() => _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends State<CustomerDetailDialog> {
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
        .select('id,status,starts_at,ends_at,memberships(name)')
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

  Future<void> saveNotes() async {
    setState(() => savingNotes = true);
    try {
      await Supabase.instance.client
          .from('customers')
          .update({'private_notes': notes.text.trim()})
          .eq('id', customerId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes saved.')));
      }
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
                value: packageId,
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
                value: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(
                    value: 'transfer',
                    child: Text('Transfer'),
                  ),
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
                value: membershipId,
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
                value: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(
                    value: 'transfer',
                    child: Text('Transfer'),
                  ),
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

  Future<void> redeemCoupon() async {
    if (coupon.text.trim().isEmpty) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'redeem_coupon',
        params: {
          'p_org': organizationId,
          'p_code': coupon.text.trim(),
          'p_customer': customerId,
        },
      );
      final data = Map<String, dynamic>.from(result as Map);
      final pct = data['discount_percent'];
      final minor = data['discount_minor'];
      final discount = pct != null
          ? '$pct% off'
          : minor != null
          ? '${formatMinor((minor as num).toInt(), currency: currency)} off'
          : 'applied';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coupon redeemed: $discount')),
        );
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
                        alignment: Alignment.centerRight,
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
                      ...memberships.map(
                        (m) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            (m['memberships'] as Map?)?['name'] ??
                                'Membership',
                          ),
                          subtitle: Text(
                            '${m['status']} • until ${DateTime.parse(m['ends_at']).toLocal().toString().substring(0, 10)}',
                          ),
                        ),
                      ),
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
