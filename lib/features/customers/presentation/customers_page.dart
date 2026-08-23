import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local/local_store_provider.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';
import 'customer_detail_dialog.dart';

const _pageSize = 25;

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  bool hasMore = false;
  int page = 0;
  String role = 'staff';
  String? organizationId;
  final search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      page = 0;
      load();
    });
  }

  Future<void> load() async {
    final organization = await ref.read(activeOrganizationProvider.future);
    organizationId = organization;
    role = await ref.read(activeRoleProvider.future) ?? 'staff';
    if (organization == null) return;

    final searchText = search.text.trim();
    try {
      var query = Supabase.instance.client
          .from('customers')
          .select()
          .eq('organization_id', organization)
          .isFilter('deleted_at', null);
      if (searchText.isNotEmpty) {
        query = query.ilike('name', '%$searchText%');
      }
      final result = await query
          .order('name')
          .range(page * _pageSize, page * _pageSize + _pageSize - 1);
      if (mounted) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(result);
          hasMore = rows.length == _pageSize;
          loading = false;
        });
      }
    } catch (_) {
      // Offline (or the request failed): fall back to the local mirror
      // WorkspaceMirror keeps warm for this org (spec slide 9). Read-only —
      // search/pagination still apply, just against whatever was cached on
      // the last successful refresh.
      final cached = await ref.read(localStoreProvider).list('customers');
      var filtered = cached
          .where(
            (r) =>
                r['organization_id'] == organization &&
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
        (a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
      );
      final pageRows = filtered
          .skip(page * _pageSize)
          .take(_pageSize)
          .toList();
      if (mounted) {
        setState(() {
          rows = pageRows;
          hasMore = pageRows.length == _pageSize;
          loading = false;
        });
      }
    }
  }

  Future<void> add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final organization = await ref.read(activeOrganizationProvider.future);
    if (organization == null) return;

    // Local-first write (spec slide 9): save locally, queue the operation,
    // then let SyncService push it to Supabase — immediately if online, on
    // the next connectivity change or manual retry otherwise. Customer
    // create/update is the one entity safe to write offline; booking and
    // payments stay server-authoritative through their RPCs.
    final id = const Uuid().v4();
    final data = {
      'id': id,
      'organization_id': organization,
      'name': name.text.trim(),
      'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
      'email': email.text.trim().isEmpty ? null : email.text.trim(),
    };
    final sync = ref.read(syncServiceProvider);
    await sync.enqueue(
      SyncOperation(
        operationId: id,
        entity: 'customers',
        entityId: id,
        operation: 'create_customer',
        payload: data,
      ),
    );
    await sync.drain();
    await load();
    if (mounted && !rows.any((r) => r['id'] == id)) {
      // Still pending (offline, or the immediate drain failed) — show it
      // optimistically until SyncService confirms it synced.
      setState(
        () => rows = [
          {...data, 'no_show_count': 0, 'total_spent_minor': 0, '_pending': true},
          ...rows,
        ],
      );
    }
  }

  Future<void> openDetail(Map<String, dynamic> row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => CustomerDetailDialog(customer: row, role: role),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              l10n.pageTitleCustomers,
              style: Theme.of(context).textTheme.headlineSmall,
            );
            final searchField = TextField(
              controller: search,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.commonSearch,
              ),
            );
            // A fixed 250px search box next to the title only has room to
            // breathe on a tablet/desktop-width layout — on a narrow phone
            // it would squeeze the title into a sliver, so stack instead.
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 12),
                  searchField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                SizedBox(width: 250, child: searchField),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (loading)
          for (int i = 0; i < 6; i++) ...[
            const SkeletonCard(),
            const SizedBox(height: 12),
          ],
        if (!loading && rows.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(message: l10n.commonNoResults),
            ),
          ),
        ...rows.map((row) {
          final pending = row['_pending'] == true;
          return Card(
            child: ListTile(
              onTap: pending ? null : () => openDetail(row),
              title: Text(row['name']),
              subtitle: Text(
                '${row['phone'] ?? ''} • no-shows ${row['no_show_count']}',
              ),
              trailing: pending
                  ? const Tooltip(
                      message: 'Waiting to sync',
                      child: Icon(Icons.sync, size: 18),
                    )
                  : Text('${(row['total_spent_minor'] as num) / 100}'),
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
  );
  }
}
