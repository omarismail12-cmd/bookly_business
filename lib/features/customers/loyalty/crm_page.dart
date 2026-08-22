import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';

class CrmPage extends ConsumerStatefulWidget {
  const CrmPage({super.key});

  @override
  ConsumerState<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends ConsumerState<CrmPage> {
  List<Map<String, dynamic>> customers = [];
  Map<String, int> points = {};
  String segment = 'all';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;

    final c = Supabase.instance.client;
    final r = await c
        .from('customers')
        .select()
        .eq('organization_id', o)
        .isFilter('deleted_at', null)
        .order('name')
        .limit(500);

    final ids = List<Map<String, dynamic>>.from(
      r,
    ).map((x) => x['id'] as String).toList();

    final p = <String, int>{};
    if (ids.isNotEmpty) {
      final l = await c
          .from('loyalty_accounts')
          .select('customer_id,points')
          .inFilter('customer_id', ids);

      for (final x in l) {
        p[x['customer_id']] = ((x['points'] as num?)?.toInt() ?? 0);
      }
    }

    if (mounted) {
      setState(() {
        customers = List<Map<String, dynamic>>.from(r);
        points = p;
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filtered {
    if (segment == 'all') return customers;
    if (segment == 'vip') {
      return customers
          .where((x) => (x['total_spent_minor'] as num? ?? 0) >= 100000)
          .toList();
    }
    if (segment == 'inactive') {
      return customers.where((x) {
        final v = x['last_visit_at'];
        return v == null ||
            DateTime.parse(
              v,
            ).isBefore(DateTime.now().subtract(const Duration(days: 30)));
      }).toList();
    }
    if (segment == 'no_show') {
      return customers
          .where((x) => (x['no_show_count'] as num? ?? 0) >= 3)
          .toList();
    }
    return customers.where((x) => x['last_visit_at'] == null).toList();
  }

  Future<void> addCustomer() async {
    final n = TextEditingController();
    final e = TextEditingController();
    final p = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: e,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: p,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, n.text.trim().isNotEmpty),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final o = await ref.read(activeOrganizationProvider.future);
    await Supabase.instance.client.from('customers').insert({
      'organization_id': o,
      'name': n.text.trim(),
      'email': e.text.trim().isEmpty ? null : e.text.trim(),
      'phone': p.text.trim().isEmpty ? null : p.text.trim(),
    });

    await load();
  }

  Future<void> campaign() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;

    final n = TextEditingController(text: 'Win Back Customers');
    final m = TextEditingController(
      text: 'We miss you! Enjoy 20% off your next visit.',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create campaign'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'Campaign name'),
            ),
            TextField(
              controller: m,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message'),
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
            child: const Text('Save draft'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await Supabase.instance.client.from('campaigns').insert({
        'organization_id': o,
        'name': n.text.trim(),
        'segment': 'inactive_30',
        'channel': 'email',
        'message': m.text.trim(),
        'status': 'draft',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign saved as draft.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addCustomer,
      icon: const Icon(Icons.person_add),
      label: const Text('Customer'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CRM • Loyalty • Campaigns',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: campaign,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Campaign'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: segment == 'all',
                      onSelected: (_) => setState(() => segment = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('VIP'),
                      selected: segment == 'vip',
                      onSelected: (_) => setState(() => segment = 'vip'),
                    ),
                    ChoiceChip(
                      label: const Text('Inactive 30d'),
                      selected: segment == 'inactive',
                      onSelected: (_) => setState(() => segment = 'inactive'),
                    ),
                    ChoiceChip(
                      label: const Text('No-show risk'),
                      selected: segment == 'no_show',
                      onSelected: (_) => setState(() => segment = 'no_show'),
                    ),
                    ChoiceChip(
                      label: const Text('First visit'),
                      selected: segment == 'first',
                      onSelected: (_) => setState(() => segment = 'first'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${filtered.length} customers',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...filtered.map((x) {
                  final pts = points[x['id']] ?? 0;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (x['name'] ?? '?')
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(x['name'] ?? ''),
                      subtitle: Text(
                        '${x['email'] ?? ''} • no-shows ${x['no_show_count'] ?? 0}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$pts pts'),
                          Text(
                            formatMinor(
                              (x['total_spent_minor'] as num? ?? 0).toInt(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
  );
}
