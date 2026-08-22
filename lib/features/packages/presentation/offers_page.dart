import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/skeleton.dart';

/// Catalog management for packages, memberships and coupons. Selling a
/// package/membership to a specific customer, or redeeming a coupon,
/// happens from the customer detail dialog (Customers page) — this page is
/// the owner/manager-only catalog editor, consistent with how Services
/// works for the appointment catalog.
class OffersPage extends ConsumerStatefulWidget {
  const OffersPage({super.key});

  @override
  ConsumerState<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends ConsumerState<OffersPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Text(
            AppLocalizations.of(context).pageTitleOffers,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        TabBar(
          controller: tabs,
          tabs: const [
            Tab(text: 'Packages'),
            Tab(text: 'Memberships'),
            Tab(text: 'Coupons'),
          ],
        ),
        const Expanded(
          child: TabBarView(
            children: [_PackagesTab(), _MembershipsTab(), _CouponsTab()],
          ),
        ),
      ],
    ),
  );
}

class _PackagesTab extends ConsumerStatefulWidget {
  const _PackagesTab();
  @override
  ConsumerState<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<_PackagesTab> {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> services = [];
  bool loading = true;
  String? organizationId;
  String currency = 'USD';

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    organizationId = o;
    if (o == null) return;
    currency = await ref.read(activeCurrencyProvider.future);
    final c = Supabase.instance.client;
    final r = await c
        .from('packages')
        .select('*,services(name)')
        .eq('organization_id', o)
        .order('name');
    final s = await c
        .from('services')
        .select('id,name')
        .eq('organization_id', o)
        .isFilter('deleted_at', null)
        .order('name');
    if (mounted) {
      setState(() {
        rows = List<Map<String, dynamic>>.from(r);
        services = List<Map<String, dynamic>>.from(s);
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final name = TextEditingController();
    final price = TextEditingController(text: '10000');
    final uses = TextEditingController(text: '5');
    final expires = TextEditingController(text: '90');
    String? serviceId = services.isNotEmpty
        ? services.first['id'] as String
        : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New package'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                DropdownButtonFormField<String>(
                  value: serviceId,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: services
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => serviceId = v),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (minor units)',
                  ),
                ),
                TextField(
                  controller: uses,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total uses'),
                ),
                TextField(
                  controller: expires,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expires after (days, optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || organizationId == null) return;
    await Supabase.instance.client.from('packages').insert({
      'organization_id': organizationId,
      'name': name.text.trim(),
      'service_id': serviceId,
      'price_minor': int.tryParse(price.text.trim()) ?? 0,
      'total_uses': int.tryParse(uses.text.trim()) ?? 1,
      'expires_days': int.tryParse(expires.text.trim()),
    });
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const SkeletonList(itemCount: 5, leadingCircle: false)
        : ListView(
            padding: const EdgeInsets.all(16),
            children: rows.isEmpty
                ? [const Text('No packages yet.')]
                : rows
                      .map(
                        (r) => Card(
                          child: ListTile(
                            title: Text(r['name']),
                            subtitle: Text(
                              '${(r['services'] as Map?)?['name'] ?? 'Any service'} • '
                              '${r['total_uses']} uses'
                              '${r['expires_days'] != null ? ' • expires in ${r['expires_days']}d' : ''}'
                              '${r['active'] == false ? ' • inactive' : ''}',
                            ),
                            trailing: Text(
                              formatMinor(
                                (r['price_minor'] as num).toInt(),
                                currency: currency,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
          ),
  );
}

class _MembershipsTab extends ConsumerStatefulWidget {
  const _MembershipsTab();
  @override
  ConsumerState<_MembershipsTab> createState() => _MembershipsTabState();
}

class _MembershipsTabState extends ConsumerState<_MembershipsTab> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? organizationId;
  String currency = 'USD';

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    organizationId = o;
    if (o == null) return;
    currency = await ref.read(activeCurrencyProvider.future);
    final r = await Supabase.instance.client
        .from('memberships')
        .select()
        .eq('organization_id', o)
        .order('name');
    if (mounted) {
      setState(() {
        rows = List<Map<String, dynamic>>.from(r);
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final name = TextEditingController();
    final price = TextEditingController(text: '5000');
    final discount = TextEditingController(text: '10');
    final duration = TextEditingController(text: '30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New membership'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (minor units)',
                ),
              ),
              TextField(
                controller: discount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount percent',
                ),
              ),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (days)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || organizationId == null) return;
    await Supabase.instance.client.from('memberships').insert({
      'organization_id': organizationId,
      'name': name.text.trim(),
      'price_minor': int.tryParse(price.text.trim()) ?? 0,
      'discount_percent': double.tryParse(discount.text.trim()) ?? 0,
      'duration_days': int.tryParse(duration.text.trim()) ?? 30,
    });
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const SkeletonList(itemCount: 5, leadingCircle: false)
        : ListView(
            padding: const EdgeInsets.all(16),
            children: rows.isEmpty
                ? [const Text('No memberships yet.')]
                : rows
                      .map(
                        (r) => Card(
                          child: ListTile(
                            title: Text(r['name']),
                            subtitle: Text(
                              '${r['discount_percent']}% off • ${r['duration_days']} days'
                              '${r['active'] == false ? ' • inactive' : ''}',
                            ),
                            trailing: Text(
                              formatMinor(
                                (r['price_minor'] as num).toInt(),
                                currency: currency,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
          ),
  );
}

class _CouponsTab extends ConsumerStatefulWidget {
  const _CouponsTab();
  @override
  ConsumerState<_CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends ConsumerState<_CouponsTab> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? organizationId;
  String currency = 'USD';

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    organizationId = o;
    if (o == null) return;
    currency = await ref.read(activeCurrencyProvider.future);
    final r = await Supabase.instance.client
        .from('coupons')
        .select()
        .eq('organization_id', o)
        .order('code');
    if (mounted) {
      setState(() {
        rows = List<Map<String, dynamic>>.from(r);
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final code = TextEditingController();
    final percent = TextEditingController(text: '10');
    final limit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New coupon'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              TextField(
                controller: percent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount percent',
                ),
              ),
              TextField(
                controller: limit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Usage limit (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              code.text.trim().isNotEmpty,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || organizationId == null) return;
    await Supabase.instance.client.from('coupons').insert({
      'organization_id': organizationId,
      'code': code.text.trim().toUpperCase(),
      'discount_percent': double.tryParse(percent.text.trim()),
      'usage_limit': int.tryParse(limit.text.trim()),
    });
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: loading
        ? const SkeletonList(itemCount: 5, leadingCircle: false)
        : ListView(
            padding: const EdgeInsets.all(16),
            children: rows.isEmpty
                ? [const Text('No coupons yet.')]
                : rows
                      .map(
                        (r) => Card(
                          child: ListTile(
                            title: Text(r['code']),
                            subtitle: Text(
                              '${r['usage_count']}${r['usage_limit'] != null ? '/${r['usage_limit']}' : ''} used'
                              '${r['expires_at'] != null ? ' • expires ${DateTime.parse(r['expires_at']).toLocal().toString().substring(0, 10)}' : ''}'
                              '${r['active'] == false ? ' • inactive' : ''}',
                            ),
                            trailing: Text(
                              r['discount_percent'] != null
                                  ? '${r['discount_percent']}%'
                                  : formatMinor(
                                      ((r['discount_minor'] as num?) ?? 0)
                                          .toInt(),
                                      currency: currency,
                                    ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
          ),
  );
}
