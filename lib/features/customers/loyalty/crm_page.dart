import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/skeleton.dart';

/// Maps the UI's segment filter keys to the keys understood by the
/// customer_segment() RPC (supabase/migrations/0003, 0010), so a campaign's
/// stored segment can later be expanded server-side via
/// generate_campaign_recipients().
const _pageSize = 25;

const Map<String, String> _segmentToDbKey = {
  'all': 'all',
  'vip': 'vip',
  'inactive': 'inactive_30',
  'no_show': 'frequent_no_show',
  'first': 'first_visit',
  'birthday': 'birthday_month',
};

class CrmPage extends ConsumerStatefulWidget {
  const CrmPage({super.key});

  @override
  ConsumerState<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends ConsumerState<CrmPage> {
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> campaigns = [];
  Map<String, int> points = {};
  String segment = 'all';
  bool loading = true;
  String? organizationId;
  String currency = 'USD';
  int page = 0;
  bool hasMore = false;

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
    // Only the "all" segment is server-paginated; the other segments filter
    // client-side over a capped batch, so paginating them would make counts
    // (e.g. "3 customers" for a VIP page) misleading.
    var query = c
        .from('customers')
        .select()
        .eq('organization_id', o)
        .isFilter('deleted_at', null)
        .order('name');
    final r = segment == 'all'
        ? await query.range(page * _pageSize, page * _pageSize + _pageSize - 1)
        : await query.limit(500);

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

    final camp = await c
        .from('campaigns')
        .select()
        .eq('organization_id', o)
        .order('created_at', ascending: false)
        .limit(20);

    if (mounted) {
      setState(() {
        customers = List<Map<String, dynamic>>.from(r);
        hasMore = segment == 'all' && customers.length == _pageSize;
        points = p;
        campaigns = List<Map<String, dynamic>>.from(camp);
        loading = false;
      });
    }
  }

  void changeSegment(String value) {
    setState(() {
      segment = value;
      page = 0;
    });
    load();
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
    if (segment == 'birthday') {
      final month = DateTime.now().month;
      return customers.where((x) {
        final b = x['birthday'];
        return b != null && DateTime.parse(b).month == month;
      }).toList();
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
    final o = organizationId;
    if (o == null) return;

    final n = TextEditingController(text: 'Win Back Customers');
    final m = TextEditingController(
      text: 'We miss you! Enjoy 20% off your next visit.',
    );
    String channel = 'push';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            'Create campaign • ${_segmentLabel(segment)} segment',
          ),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: channel,
                decoration: const InputDecoration(labelText: 'Channel'),
                items: const [
                  DropdownMenuItem(
                    value: 'push',
                    child: Text('Push notification'),
                  ),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                ],
                onChanged: (v) => setLocal(() => channel = v ?? 'push'),
              ),
              if (channel != 'push')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Email/SMS delivery needs a provider that is not configured '
                    'in this environment; the campaign will be recorded and its '
                    'audience generated, but not actually delivered.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
      ),
    );

    if (ok == true) {
      await Supabase.instance.client.from('campaigns').insert({
        'organization_id': o,
        'name': n.text.trim(),
        'segment': _segmentToDbKey[segment] ?? 'all',
        'channel': channel,
        'message': m.text.trim(),
        'status': 'draft',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign saved as draft.')),
        );
      }
      await load();
    }
  }

  Future<void> sendCampaign(String id) async {
    try {
      final queued = await Supabase.instance.client.rpc(
        'send_campaign',
        params: {'p_campaign': id},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign sent to $queued recipient(s).')),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send campaign: $e')));
      }
    }
  }

  String _segmentLabel(String key) => switch (key) {
    'all' => 'All customers',
    'vip' => 'VIP',
    'inactive' => 'Inactive 30d',
    'no_show' => 'No-show risk',
    'first' => 'First visit',
    'birthday' => 'Birthday this month',
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addCustomer,
      icon: const Icon(Icons.person_add),
      label: Text(l10n.crmAddCustomer),
    ),
    body: loading
        ? SkeletonList(
            itemCount: 6,
            header: Text(
              l10n.pageTitleCrm,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pageTitleCrm,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: campaign,
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text(l10n.crmCreateCampaign),
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
                      onSelected: (_) => changeSegment('all'),
                    ),
                    ChoiceChip(
                      label: const Text('VIP'),
                      selected: segment == 'vip',
                      onSelected: (_) => changeSegment('vip'),
                    ),
                    ChoiceChip(
                      label: const Text('Inactive 30d'),
                      selected: segment == 'inactive',
                      onSelected: (_) => changeSegment('inactive'),
                    ),
                    ChoiceChip(
                      label: const Text('No-show risk'),
                      selected: segment == 'no_show',
                      onSelected: (_) => changeSegment('no_show'),
                    ),
                    ChoiceChip(
                      label: const Text('First visit'),
                      selected: segment == 'first',
                      onSelected: (_) => changeSegment('first'),
                    ),
                    ChoiceChip(
                      label: const Text('Birthday this month'),
                      selected: segment == 'birthday',
                      onSelected: (_) => changeSegment('birthday'),
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
                              currency: currency,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (segment == 'all' && (page > 0 || hasMore))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: page > 0
                              ? () {
                                  setState(() => page--);
                                  load();
                                }
                              : null,
                          child: Text(l10n.commonPrevious),
                        ),
                        const SizedBox(width: 16),
                        Text('Page ${page + 1}'),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: hasMore
                              ? () {
                                  setState(() => page++);
                                  load();
                                }
                              : null,
                          child: Text(l10n.commonNext),
                        ),
                      ],
                    ),
                  ),
                if (campaigns.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Campaigns',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...campaigns.map(
                    (cmp) => Card(
                      child: ListTile(
                        title: Text(cmp['name'] ?? ''),
                        subtitle: Text(
                          '${cmp['segment']} • ${cmp['channel']} • ${cmp['status']}',
                        ),
                        trailing: cmp['status'] == 'sent'
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : TextButton(
                                onPressed: () => sendCampaign(cmp['id']),
                                child: const Text('Send'),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
  }
}
