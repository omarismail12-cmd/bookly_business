import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/status_labels.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

/// Maps the UI's segment filter keys to the keys understood by the
/// customer_segment() RPC (supabase/migrations/0003, 0010). A campaign
/// created here just stores this mapped segment key; this file never calls
/// generate_campaign_recipients() or customer_segment() itself —
/// sendCampaign() below calls send_campaign(), which is what expands the
/// stored segment into campaign_recipients server-side.
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
  List<Customer> customers = [];
  List<Map<String, dynamic>> campaigns = [];
  Map<String, int> points = {};
  String segment = 'all';
  bool loading = true;
  Object? error;
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
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final o = await ref.read(activeOrganizationProvider.future);
      organizationId = o;
      if (o == null) return;
      currency = await ref.read(activeCurrencyProvider.future);

      final repo = ref.read(customersRepositoryProvider);
      // Only the "all" segment is server-paginated; the other segments filter
      // client-side over a capped batch, so paginating them would make counts
      // (e.g. "3 customers" for a VIP page) misleading.
      final r = await repo.list(
        organizationId: o,
        page: page,
        pageSize: _pageSize,
        paginate: segment == 'all',
        limit: 500,
      );

      final ids = r.map((x) => x.id).toList();
      final p = await repo.loyaltyPointsForCustomers(ids);
      final camp = await repo.campaigns(o);

      if (mounted) {
        setState(() {
          customers = r;
          hasMore = segment == 'all' && customers.length == _pageSize;
          points = p;
          campaigns = camp;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  void changeSegment(String value) {
    setState(() {
      segment = value;
      page = 0;
    });
    load();
  }

  List<Customer> get filtered {
    if (segment == 'all') return customers;
    if (segment == 'vip') {
      return customers.where((x) => x.totalSpentMinor >= 100000).toList();
    }
    if (segment == 'inactive') {
      return customers.where((x) {
        final v = x.lastVisitAt;
        return v == null ||
            v.isBefore(DateTime.now().subtract(const Duration(days: 30)));
      }).toList();
    }
    if (segment == 'no_show') {
      return customers.where((x) => x.noShowCount >= 3).toList();
    }
    if (segment == 'birthday') {
      final month = DateTime.now().month;
      return customers.where((x) => x.birthday?.month == month).toList();
    }
    if (segment == 'first') {
      return customers.where((x) => x.lastVisitAt == null).toList();
    }
    return customers;
  }

  Future<void> addCustomer() async {
    final l10n = AppLocalizations.of(context);
    final n = TextEditingController();
    final p = TextEditingController();
    final e = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.customersAddDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: InputDecoration(labelText: l10n.commonName),
            ),
            TextField(
              controller: p,
              decoration: InputDecoration(labelText: l10n.commonPhone),
            ),
            TextField(
              controller: e,
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
            onPressed: () => Navigator.pop(context, n.text.trim().isNotEmpty),
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;

    // Local-first write, matching customers_page.dart: queue through
    // SyncService so customer creation is offline-safe here too, instead of
    // writing straight to Supabase.
    final id = const Uuid().v4();
    final data = {
      'id': id,
      'organization_id': o,
      'name': n.text.trim(),
      'phone': p.text.trim().isEmpty ? null : p.text.trim(),
      'email': e.text.trim().isEmpty ? null : e.text.trim(),
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
    if (mounted && !customers.any((r) => r.id == id)) {
      // Still pending (offline, or the immediate drain failed) — show it
      // optimistically until SyncService confirms it synced.
      setState(
        () => customers = [
          Customer(
            id: id,
            organizationId: o,
            name: data['name']!,
            phone: data['phone'],
            email: data['email'],
            pending: true,
          ),
          ...customers,
        ],
      );
    }
  }

  Future<void> campaign() async {
    final o = organizationId;
    if (o == null) return;
    final l10n = AppLocalizations.of(context);

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
            l10n.crmCreateCampaignTitle(_segmentLabel(l10n, segment)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: n,
                decoration: InputDecoration(labelText: l10n.crmCampaignNameLabel),
              ),
              TextField(
                controller: m,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.crmMessageLabel),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: channel,
                decoration: InputDecoration(labelText: l10n.crmChannelLabel),
                items: [
                  DropdownMenuItem(
                    value: 'push',
                    child: Text(l10n.crmChannelPush),
                  ),
                  DropdownMenuItem(value: 'email', child: Text(l10n.crmChannelEmail)),
                  DropdownMenuItem(value: 'sms', child: Text(l10n.crmChannelSms)),
                ],
                onChanged: (v) => setLocal(() => channel = v ?? 'push'),
              ),
              if (channel != 'push')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.crmChannelNoProviderWarning,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
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
              child: Text(l10n.crmSaveDraft),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await ref.read(customersRepositoryProvider).createCampaignDraft(
        organizationId: o,
        name: n.text.trim(),
        segment: _segmentToDbKey[segment] ?? 'all',
        channel: channel,
        message: m.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.crmCampaignSavedDraft)),
        );
      }
      await load();
    }
  }

  Future<void> sendCampaign(String id) async {
    final l10n = AppLocalizations.of(context);
    try {
      final channel = campaigns.firstWhere((c) => c['id'] == id)['channel'];
      final queued = await ref
          .read(customersRepositoryProvider)
          .sendCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              channel == 'push'
                  ? l10n.crmCampaignSentPush('$queued')
                  : l10n.crmCampaignSentNoProvider('$queued', channel as String),
            ),
          ),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.crmCampaignSendFailed('$e'))),
        );
      }
    }
  }

  /// Accepts both the UI's segment filter keys ('inactive') and the DB
  /// keys campaigns.segment actually stores ('inactive_30') — see
  /// _segmentToDbKey above.
  String _segmentLabel(AppLocalizations l10n, String key) => switch (key) {
    'all' => l10n.crmSegmentAll,
    'vip' => l10n.crmSegmentVip,
    'inactive' || 'inactive_30' => l10n.crmSegmentInactive,
    'no_show' || 'frequent_no_show' => l10n.crmSegmentNoShow,
    'first' || 'first_visit' => l10n.crmSegmentFirstVisit,
    'birthday' || 'birthday_month' => l10n.crmSegmentBirthday,
    _ => key,
  };

  String _channelLabel(AppLocalizations l10n, String channel) => switch (channel) {
    'push' => l10n.crmChannelPush,
    'email' => l10n.crmChannelEmail,
    'sms' => l10n.crmChannelSms,
    _ => channel,
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
        : error != null
        ? AsyncErrorView(error: error!, onRetry: load)
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
                      label: Text(l10n.crmSegmentAll),
                      selected: segment == 'all',
                      onSelected: (_) => changeSegment('all'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.crmSegmentVip),
                      selected: segment == 'vip',
                      onSelected: (_) => changeSegment('vip'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.crmSegmentInactive),
                      selected: segment == 'inactive',
                      onSelected: (_) => changeSegment('inactive'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.crmSegmentNoShow),
                      selected: segment == 'no_show',
                      onSelected: (_) => changeSegment('no_show'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.crmSegmentFirstVisit),
                      selected: segment == 'first',
                      onSelected: (_) => changeSegment('first'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.crmSegmentBirthday),
                      selected: segment == 'birthday',
                      onSelected: (_) => changeSegment('birthday'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.crmCustomerCount(filtered.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...filtered.map((x) {
                  final pts = points[x.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
                    child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (x.name.isEmpty ? '?' : x.name)
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(x.name),
                      subtitle: Text(
                        '${x.email ?? ''} • ${l10n.customersSubtitleNoShows(x.noShowCount)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(l10n.crmPointsAbbrev(pts)),
                          Text(
                            formatMinor(x.totalSpentMinor, currency: currency),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
                if (campaigns.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.crmCampaignsHeading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...campaigns.map(
                    (cmp) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
                      child: Card(
                        child: ListTile(
                          title: Text(cmp['name'] ?? ''),
                          subtitle: Text(
                            '${_segmentLabel(l10n, cmp['segment'] as String? ?? '')} • '
                            '${_channelLabel(l10n, cmp['channel'] as String? ?? '')} • '
                            '${humanStatusLabel(l10n, cmp['status'] as String? ?? '')}',
                          ),
                          trailing: cmp['status'] == 'sent'
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : cmp['status'] == 'undeliverable'
                              ? Tooltip(
                                  message: l10n.crmUndeliverableTooltip,
                                  child: const Icon(
                                    Icons.error_outline,
                                    color: Colors.orange,
                                  ),
                                )
                              : TextButton(
                                  onPressed: () => sendCampaign(cmp['id']),
                                  child: Text(l10n.crmSend),
                                ),
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
