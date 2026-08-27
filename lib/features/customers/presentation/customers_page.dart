import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';
import 'customer_detail_dialog.dart';

const _pageSize = 25;

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  List<Customer> rows = [];
  bool loading = true;
  bool hasMore = false;
  int page = 0;
  String role = 'staff';
  String? organizationId;
  String currency = 'USD';
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
    currency = await ref.read(activeCurrencyProvider.future);
    if (organization == null) return;

    // Offline (or the request failed): CustomersRepository.list falls back
    // to the local mirror WorkspaceMirror keeps warm for this org (spec
    // slide 9) when offlineFallback is true. Read-only — search/pagination
    // still apply, just against whatever was cached on the last successful
    // refresh.
    final result = await ref.read(customersRepositoryProvider).list(
      organizationId: organization,
      search: search.text,
      page: page,
      pageSize: _pageSize,
      offlineFallback: true,
    );
    if (mounted) {
      setState(() {
        rows = result;
        hasMore = rows.length == _pageSize;
        loading = false;
      });
    }
  }

  Future<void> add() async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.customersAddDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.commonName),
            ),
            TextField(
              controller: phone,
              decoration: InputDecoration(labelText: l10n.commonPhone),
            ),
            TextField(
              controller: email,
              decoration: InputDecoration(labelText: l10n.loginEmail),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonSave),
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
    if (mounted && !rows.any((r) => r.id == id)) {
      // Still pending (offline, or the immediate drain failed) — show it
      // optimistically until SyncService confirms it synced.
      setState(
        () => rows = [
          Customer(
            id: id,
            organizationId: organization,
            name: data['name']!,
            phone: data['phone'],
            email: data['email'],
            pending: true,
          ),
          ...rows,
        ],
      );
    }
  }

  Future<void> openDetail(Customer row) async {
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
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
            child: Card(
              child: ListTile(
                onTap: row.pending ? null : () => openDetail(row),
                title: Text(row.name),
                subtitle: Text(
                  '${row.phone ?? ''} • ${l10n.customersSubtitleNoShows(row.noShowCount)}',
                ),
                trailing: row.pending
                    ? Tooltip(
                        message: l10n.customersWaitingToSync,
                        child: const Icon(Icons.sync, size: 18),
                      )
                    : Text(
                        formatMinor(row.totalSpentMinor, currency: currency),
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
  );
  }
}
