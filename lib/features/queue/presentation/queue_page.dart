import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/security/org_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/async_state.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../services/data/services_repository.dart';
import '../../staff/data/staff_repository.dart';
import '../data/queue_repository.dart';
import '../domain/queue_entry.dart';

class QueuePage extends ConsumerStatefulWidget {
  const QueuePage({super.key});
  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  List<QueueEntry> rows = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> staff = [];
  bool loading = true;
  int page = 0;
  bool hasMore = false;
  RealtimeChannel? channel;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    if (channel != null) Supabase.instance.client.removeChannel(channel!);
    super.dispose();
  }

  Future<void> subscribe(String org) async {
    channel = ref.read(queueRepositoryProvider).subscribe(org, load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    final queueRepo = ref.read(queueRepositoryProvider);
    final r = await queueRepo.listActive(o, page: page);
    final cu = await queueRepo.listCustomerIdName(o);
    final se = await ref.read(servicesRepositoryProvider).listIdName(o);
    final st = await ref.read(staffRepositoryProvider).listIdNameActive(o);
    if (channel == null) await subscribe(o);
    if (mounted) {
      setState(() {
        rows = r;
        hasMore = rows.length == queuePageSize;
        customers = cu;
        services = se;
        staff = st;
        loading = false;
      });
    }
  }

  Future<void> advance(String id, String status) async {
    await ref.read(queueRepositoryProvider).changeStatus(queueId: id, status: status);
    await load();
  }

  Future<void> addWalkIn() async {
    final l10n = AppLocalizations.of(context);
    String? cId, sId, stId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.queueAddWalkInDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: cId,
                decoration: InputDecoration(labelText: l10n.queueCustomerLabel),
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
                initialValue: sId,
                decoration: InputDecoration(labelText: l10n.queueServiceLabel),
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
                initialValue: stId,
                decoration: InputDecoration(
                  labelText: l10n.queueStaffOptionalLabel,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.queueAnyStaff),
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
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, cId != null && sId != null),
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final id = await ref.read(queueRepositoryProvider).addWalkIn(
        customerId: cId!,
        serviceId: sId!,
        staffId: stId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.queueWalkInAdded(id.toString().substring(0, 8))),
          ),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.queueAddWalkInFailed('$e'))),
        );
      }
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
                  final customer = row.customerName ?? l10n.commonCustomerFallback;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
                    child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${row.queueNumber}'),
                      ),
                      title: Text(customer),
                      subtitle: Text(
                        '${row.serviceName ?? ''} • ${row.estimatedWaitMin} min',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (s) => advance(row.id, s),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'called', child: Text(l10n.queueCall)),
                          PopupMenuItem(
                            value: 'in_service',
                            child: Text(l10n.queueStart),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Text(l10n.apptComplete),
                          ),
                          PopupMenuItem(
                            value: 'cancelled',
                            child: Text(l10n.commonCancel),
                          ),
                        ],
                      ),
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
                        Text(l10n.commonPage(page + 1)),
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
