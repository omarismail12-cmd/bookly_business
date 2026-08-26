import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../services/data/services_repository.dart';
import '../data/packages_repository.dart';
import '../domain/package_offer.dart';

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
          tabs: [
            Tab(text: AppLocalizations.of(context).offersTabPackages),
            Tab(text: AppLocalizations.of(context).offersTabMemberships),
            Tab(text: AppLocalizations.of(context).offersTabCoupons),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: const [_PackagesTab(), _MembershipsTab(), _CouponsTab()],
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
  List<PackageOffer> rows = [];
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
    final r = await ref.read(packagesRepositoryProvider).listPackages(o);
    final s = await ref.read(servicesRepositoryProvider).listIdName(o);
    if (mounted) {
      setState(() {
        rows = r;
        services = s;
        loading = false;
      });
    }
  }

  Future<void> edit({PackageOffer? existing}) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: existing?.name);
    final price = TextEditingController(
      text: '${existing?.priceMinor ?? 10000}',
    );
    final uses = TextEditingController(text: '${existing?.totalUses ?? 5}');
    final expires = TextEditingController(
      text: existing == null
          ? '90'
          : (existing.expiresDays != null ? '${existing.expiresDays}' : ''),
    );
    String? serviceId =
        existing?.serviceId ??
        (services.isNotEmpty ? services.first['id'] as String : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? l10n.offersNewPackageTitle : l10n.offersEditPackageTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l10n.commonName),
                ),
                DropdownButtonFormField<String>(
                  initialValue: serviceId,
                  decoration: InputDecoration(labelText: l10n.offersServiceLabel),
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
                  decoration: InputDecoration(
                    labelText: l10n.offersPriceMinorLabel,
                  ),
                ),
                TextField(
                  controller: uses,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.offersTotalUsesLabel),
                ),
                TextField(
                  controller: expires,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.offersExpiresAfterLabel,
                  ),
                ),
              ],
            ),
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
      ),
    );
    if (ok != true || organizationId == null) return;
    final repo = ref.read(packagesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createPackage(
          organizationId: organizationId!,
          name: name.text.trim(),
          serviceId: serviceId,
          priceMinor: int.tryParse(price.text.trim()) ?? 0,
          totalUses: int.tryParse(uses.text.trim()) ?? 1,
          expiresDays: int.tryParse(expires.text.trim()),
        );
      } else {
        await repo.updatePackage(
          id: existing.id,
          name: name.text.trim(),
          serviceId: serviceId,
          priceMinor: int.tryParse(price.text.trim()) ?? existing.priceMinor,
          totalUses: int.tryParse(uses.text.trim()) ?? existing.totalUses,
          expiresDays: int.tryParse(expires.text.trim()),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offersSavePackageFailed('$e'))),
        );
      }
    }
  }

  Future<void> toggleActive(PackageOffer row) async {
    try {
      await ref
          .read(packagesRepositoryProvider)
          .setActive('packages', row.id, !row.active);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).offersUpdatePackageFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const SkeletonList(itemCount: 5, leadingCircle: false)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: rows.isEmpty
                  ? [Text(l10n.offersNoPackagesYet)]
                  : rows
                        .map(
                          (r) => Card(
                            child: ListTile(
                              title: Text(r.name),
                              subtitle: Text(
                                '${r.serviceName ?? l10n.offersAnyService} • '
                                '${l10n.offersUsesCount(r.totalUses)}'
                                '${r.expiresDays != null ? ' • ${l10n.offersExpiresInDays(r.expiresDays!)}' : ''}'
                                '${!r.active ? ' • ${l10n.statusInactive}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatMinor(
                                      r.priceMinor,
                                      currency: currency,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) => v == 'edit'
                                        ? edit(existing: r)
                                        : toggleActive(r),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(l10n.commonEdit),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          r.active ? l10n.offersDeactivate : l10n.offersReactivate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
    );
  }
}

class _MembershipsTab extends ConsumerStatefulWidget {
  const _MembershipsTab();
  @override
  ConsumerState<_MembershipsTab> createState() => _MembershipsTabState();
}

class _MembershipsTabState extends ConsumerState<_MembershipsTab> {
  List<Membership> rows = [];
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
    final r = await ref.read(packagesRepositoryProvider).listMemberships(o);
    if (mounted) {
      setState(() {
        rows = r;
        loading = false;
      });
    }
  }

  Future<void> edit({Membership? existing}) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: existing?.name);
    final price = TextEditingController(
      text: '${existing?.priceMinor ?? 5000}',
    );
    final discount = TextEditingController(
      text: '${existing?.discountPercent ?? 10}',
    );
    final duration = TextEditingController(
      text: '${existing?.durationDays ?? 30}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? l10n.offersNewMembershipTitle : l10n.offersEditMembershipTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.commonName),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.offersPriceMinorLabel,
                ),
              ),
              TextField(
                controller: discount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.offersDiscountPercentLabel,
                ),
              ),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.offersDurationDaysLabel,
                ),
              ),
            ],
          ),
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
    if (ok != true || organizationId == null) return;
    final repo = ref.read(packagesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createMembership(
          organizationId: organizationId!,
          name: name.text.trim(),
          priceMinor: int.tryParse(price.text.trim()) ?? 0,
          discountPercent: double.tryParse(discount.text.trim()) ?? 0,
          durationDays: int.tryParse(duration.text.trim()) ?? 30,
        );
      } else {
        await repo.updateMembership(
          id: existing.id,
          name: name.text.trim(),
          priceMinor: int.tryParse(price.text.trim()) ?? existing.priceMinor,
          discountPercent:
              double.tryParse(discount.text.trim()) ?? existing.discountPercent,
          durationDays:
              int.tryParse(duration.text.trim()) ?? existing.durationDays,
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offersSaveMembershipFailed('$e'))),
        );
      }
    }
  }

  Future<void> toggleActive(Membership row) async {
    try {
      await ref
          .read(packagesRepositoryProvider)
          .setActive('memberships', row.id, !row.active);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).offersUpdateMembershipFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const SkeletonList(itemCount: 5, leadingCircle: false)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: rows.isEmpty
                  ? [Text(l10n.offersNoMembershipsYet)]
                  : rows
                        .map(
                          (r) => Card(
                            child: ListTile(
                              title: Text(r.name),
                              subtitle: Text(
                                l10n.offersDiscountOffDuration('${r.discountPercent}', r.durationDays) +
                                    (!r.active ? ' • ${l10n.statusInactive}' : ''),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatMinor(
                                      r.priceMinor,
                                      currency: currency,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) => v == 'edit'
                                        ? edit(existing: r)
                                        : toggleActive(r),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(l10n.commonEdit),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          r.active ? l10n.offersDeactivate : l10n.offersReactivate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
    );
  }
}

class _CouponsTab extends ConsumerStatefulWidget {
  const _CouponsTab();
  @override
  ConsumerState<_CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends ConsumerState<_CouponsTab> {
  List<Coupon> rows = [];
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
    final r = await ref.read(packagesRepositoryProvider).listCoupons(o);
    if (mounted) {
      setState(() {
        rows = r;
        loading = false;
      });
    }
  }

  Future<void> edit({Coupon? existing}) async {
    final l10n = AppLocalizations.of(context);
    final code = TextEditingController(text: existing?.code);
    final percent = TextEditingController(
      text: existing?.discountPercent != null
          ? '${existing!.discountPercent}'
          : (existing == null ? '10' : ''),
    );
    final limit = TextEditingController(
      text: existing?.usageLimit != null ? '${existing!.usageLimit}' : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? l10n.offersNewCouponTitle : l10n.offersEditCouponTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l10n.offersCodeLabel),
              ),
              TextField(
                controller: percent,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.offersDiscountPercentLabel,
                ),
              ),
              TextField(
                controller: limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.offersUsageLimitLabel,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              code.text.trim().isNotEmpty,
            ),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (ok != true || organizationId == null) return;
    final repo = ref.read(packagesRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createCoupon(
          organizationId: organizationId!,
          code: code.text.trim().toUpperCase(),
          discountPercent: double.tryParse(percent.text.trim()),
          usageLimit: int.tryParse(limit.text.trim()),
        );
      } else {
        await repo.updateCoupon(
          id: existing.id,
          code: code.text.trim().toUpperCase(),
          discountPercent: double.tryParse(percent.text.trim()),
          usageLimit: int.tryParse(limit.text.trim()),
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offersSaveCouponFailed('$e'))),
        );
      }
    }
  }

  Future<void> toggleActive(Coupon row) async {
    try {
      await ref
          .read(packagesRepositoryProvider)
          .setActive('coupons', row.id, !row.active);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).offersUpdateCouponFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const SkeletonList(itemCount: 5, leadingCircle: false)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: rows.isEmpty
                  ? [Text(l10n.offersNoCouponsYet)]
                  : rows
                        .map(
                          (r) => Card(
                            child: ListTile(
                              title: Text(r.code),
                              subtitle: Text(
                                (r.usageLimit != null
                                        ? l10n.offersUsedCountLimited(r.usageCount, r.usageLimit!)
                                        : l10n.offersUsedCountUnlimited(r.usageCount)) +
                                    (r.expiresAt != null
                                        ? ' • ${l10n.customerDetailExpiresOn(r.expiresAt!.toLocal().toString().substring(0, 10))}'
                                        : '') +
                                    (!r.active ? ' • ${l10n.statusInactive}' : ''),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.discountPercent != null
                                        ? '${r.discountPercent}%'
                                        : formatMinor(
                                            r.discountMinor ?? 0,
                                            currency: currency,
                                          ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) => v == 'edit'
                                        ? edit(existing: r)
                                        : toggleActive(r),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(l10n.commonEdit),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          r.active ? l10n.offersDeactivate : l10n.offersReactivate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
    );
  }
}
