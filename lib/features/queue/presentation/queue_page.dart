import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/security/org_context.dart';
import '../../../../shared/widgets/async_state.dart';
import '../../../../shared/widgets/skeleton.dart';

const _pageSize = 20;

class QueuePage extends ConsumerStatefulWidget {
  const QueuePage({super.key});
  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> staff = [];
  bool loading = true;
  int page = 0;
  bool hasMore = false;
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
        .from('queue_entries')
        .select('*,customers(name),services(name),staff(display_name)')
        .eq('organization_id', o)
        .inFilter('status', ['waiting', 'called', 'in_service'])
        .order('queue_number')
        .range(page * _pageSize, page * _pageSize + _pageSize - 1);
    final cu = await c
        .from('customers')
        .select('id,name')
        .eq('organization_id', o)
        .isFilter('deleted_at', null)
        .order('name');
    final se = await c
        .from('services')
        .select('id,name')
        .eq('organization_id', o)
        .isFilter('deleted_at', null)
        .order('name');
    final st = await c
        .from('staff')
        .select('id,display_name')
        .eq('organization_id', o)
        .eq('status', 'active')
        .order('display_name');
    if (mounted)
      setState(() {
        rows = List<Map<String, dynamic>>.from(r);
        hasMore = rows.length == _pageSize;
        customers = List<Map<String, dynamic>>.from(cu);
        services = List<Map<String, dynamic>>.from(se);
        staff = List<Map<String, dynamic>>.from(st);
        loading = false;
      });
  }

  Future<void> advance(String id, String status) async {
    await Supabase.instance.client.rpc(
      'change_queue_status',
      params: {'p_queue': id, 'p_status': status},
    );
    await load();
  }

  Future<void> addWalkIn() async {
    String? cId, sId, stId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add walk-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: cId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers
                    .map<DropdownMenuItem<String>>(
                      (x) => DropdownMenuItem<String>(
                        value: x['id'] as String,
                        child: Text((x['name'] ?? '') as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => cId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sId,
                decoration: const InputDecoration(labelText: 'Service'),
                items: services
                    .map<DropdownMenuItem<String>>(
                      (x) => DropdownMenuItem<String>(
                        value: x['id'] as String,
                        child: Text((x['name'] ?? '') as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => sId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: stId,
                decoration: const InputDecoration(
                  labelText: 'Staff (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Any staff'),
                  ),
                  ...staff.map<DropdownMenuItem<String?>>(
                    (x) => DropdownMenuItem<String?>(
                      value: x['id'] as String,
                      child: Text((x['display_name'] ?? '') as String),
                    ),
                  ),
                ],
                onChanged: (v) => setLocal(() => stId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, cId != null && sId != null),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final id = await Supabase.instance.client.rpc(
        'add_walk_in',
        params: {'p_customer': cId, 'p_service': sId, 'p_staff': stId},
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Walk-in added • ${id.toString().substring(0, 8)}'),
          ),
        );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add walk-in: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading ? null : addWalkIn,
      icon: const Icon(Icons.person_add),
      label: Text(l10n.queueAddWalkIn),
    ),
    body: loading
        ? SkeletonList(
            itemCount: 5,
            itemHeight: 76,
            header: Text(
              l10n.pageTitleQueue,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.pageTitleQueue,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyState(message: l10n.queueEmpty),
                    ),
                  ),
                ...rows.map((row) {
                  final customer =
                      (row['customers'] as Map?)?['name'] ?? 'Customer';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${row['queue_number']}'),
                      ),
                      title: Text(customer),
                      subtitle: Text(
                        '${(row['services'] as Map?)?['name'] ?? ''} • ${row['estimated_wait_min']} min',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (s) => advance(row['id'], s),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'called', child: Text('Call')),
                          PopupMenuItem(
                            value: 'in_service',
                            child: Text('Start'),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Text('Complete'),
                          ),
                          PopupMenuItem(
                            value: 'cancelled',
                            child: Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (!loading && (page > 0 || hasMore))
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
              ],
            ),
          ),
  );
  }
}
