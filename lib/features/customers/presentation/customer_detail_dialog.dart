import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/status_labels.dart';
import '../../payments/data/payments_repository.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

/// Customer 360 view: profile + notes, loyalty points, purchased packages
/// and memberships, and coupon redemption. Selling/redeeming actions are
/// gated to owner/manager/receptionist to match the payments-taking role
/// set used elsewhere (Permission.takePayments); everyone who can see the
/// Customers page can view this dialog and edit notes.
class CustomerDetailDialog extends ConsumerStatefulWidget {
  final Customer customer;
  final String role;

  const CustomerDetailDialog({
    super.key,
    required this.customer,
    required this.role,
  });

  @override
  ConsumerState<CustomerDetailDialog> createState() =>
      _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends ConsumerState<CustomerDetailDialog> {
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

  String get customerId => widget.customer.id;
  String get organizationId => widget.customer.organizationId;

  @override
  void initState() {
    super.initState();
    notes = TextEditingController(text: widget.customer.privateNotes ?? '');
    Future.microtask(load);
  }

  @override
  void dispose() {
    notes.dispose();
    coupon.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final repo = ref.read(customersRepositoryProvider);
    final org = await repo.orgCurrency(organizationId);
    final loyalty = await repo.loyaltyPoints(customerId);
    final pkgs = await repo.customerPackages(customerId);
    final mems = await repo.customerMemberships(customerId);
    final catalogPkgs = await repo.activePackagesCatalog(organizationId);
    final catalogMems = await repo.activeMembershipsCatalog(organizationId);
    if (!mounted) return;
    setState(() {
      currency = org;
      points = loyalty;
      packages = pkgs;
      memberships = mems;
      catalogPackages = catalogPkgs;
      catalogMemberships = catalogMems;
      loading = false;
    });
  }

  /// Local-first, conflict-checked edit (spec slide 9): queues through
  /// SyncService instead of writing straight to Supabase, so editing notes
  /// works offline. [baseVersion] is the customer's `version` column as
  /// last loaded — if it's moved server-side by drain time, SyncService
  /// parks the edit as a conflict instead of overwriting silently (see
  /// SyncService._applyVersionedUpdate). A still-optimistic customer row
  /// (just added, not yet synced) has no `version` yet, so the check is
  /// simply skipped for that one edit — nothing to conflict against.
  Future<void> saveNotes() async {
    setState(() => savingNotes = true);
    final l10n = AppLocalizations.of(context);
    try {
      final operationId = const Uuid().v4();
      final baseVersion = widget.customer.version;
      final sync = ref.read(syncServiceProvider);
      await sync.enqueue(
        SyncOperation(
          operationId: operationId,
          entity: 'customers',
          entityId: customerId,
          operation: 'update_customer_notes',
          payload: {
            'private_notes': notes.text.trim(),
            '_base_version': ?baseVersion,
          },
        ),
      );
      await sync.drain();
      if (!mounted) return;
      final conflicted = (await sync.conflicts()).any(
        (o) => o.operationId == operationId,
      );
      final stillPending = (await sync.store.pending()).any(
        (o) => o.operationId == operationId,
      );
      if (!mounted) return;
      final message = conflicted
          ? l10n.customerDetailNotesConflict
          : stillPending
          ? l10n.customerDetailNotesOfflinePending
          : l10n.customerDetailNotesSaved;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailSaveNotesFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => savingNotes = false);
    }
  }

  Future<void> redeemPoints() async {
    final l10n = AppLocalizations.of(context);
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.customerDetailRedeemPointsTitle),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.customerDetailPointsBalanceLabel(points)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (int.tryParse(amount.text.trim()) ?? 0) > 0,
            ),
            child: Text(l10n.customerDetailRedeem),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(customersRepositoryProvider).redeemLoyaltyPoints(
        customerId: customerId,
        points: int.parse(amount.text.trim()),
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailRedeemPointsFailed('$e'))),
        );
      }
    }
  }

  Future<void> redeemPackageUse(Map<String, dynamic> customerPackage) async {
    final l10n = AppLocalizations.of(context);
    final name = (customerPackage['packages'] as Map?)?['name'] ??
        l10n.customerDetailFallbackPackageName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.customerDetailUseOneVisitTitle),
        content: Text(
          l10n.customerDetailUseOneVisitBody(
            name as String,
            '${customerPackage['remaining_uses']}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.customerDetailUse),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(customersRepositoryProvider)
          .redeemPackageUse(customerPackage['id'] as String);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailUsePackageFailed('$e'))),
        );
      }
    }
  }

  Future<void> sellPackage() async {
    if (catalogPackages.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    String? packageId = catalogPackages.first['id'] as String;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.customerDetailSellPackageTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: packageId,
                decoration: InputDecoration(labelText: l10n.customerDetailPackageLabel),
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
                initialValue: method,
                decoration: InputDecoration(labelText: l10n.paymentMethodLabel),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text(l10n.paymentMethodCash)),
                  DropdownMenuItem(value: 'card', child: Text(l10n.paymentMethodCard)),
                  DropdownMenuItem(value: 'transfer', child: Text(l10n.paymentMethodTransfer)),
                ],
                onChanged: (v) => setLocal(() => method = v ?? 'cash'),
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
              child: Text(l10n.customerDetailSell),
            ),
          ],
        ),
      ),
    );
    if (ok != true || packageId == null) return;
    try {
      await ref.read(customersRepositoryProvider).sellPackage(
        idempotencyKey: const Uuid().v4(),
        customerId: customerId,
        packageId: packageId!,
        method: method,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailSellPackageFailed('$e'))),
        );
      }
    }
  }

  Future<void> sellMembership() async {
    if (catalogMemberships.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    String? membershipId = catalogMemberships.first['id'] as String;
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.customerDetailSellMembershipTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: membershipId,
                decoration: InputDecoration(labelText: l10n.customerDetailMembershipLabel),
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
                initialValue: method,
                decoration: InputDecoration(labelText: l10n.paymentMethodLabel),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text(l10n.paymentMethodCash)),
                  DropdownMenuItem(value: 'card', child: Text(l10n.paymentMethodCard)),
                  DropdownMenuItem(value: 'transfer', child: Text(l10n.paymentMethodTransfer)),
                ],
                onChanged: (v) => setLocal(() => method = v ?? 'cash'),
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
              child: Text(l10n.customerDetailSell),
            ),
          ],
        ),
      ),
    );
    if (ok != true || membershipId == null) return;
    try {
      await ref.read(customersRepositoryProvider).purchaseMembership(
        idempotencyKey: const Uuid().v4(),
        customerId: customerId,
        membershipId: membershipId!,
        method: method,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailSellMembershipFailed('$e'))),
        );
      }
    }
  }

  Map<String, dynamic>? _catalogMembership(String? membershipId) {
    if (membershipId == null) return null;
    for (final m in catalogMemberships) {
      if (m['id'] == membershipId) return m;
    }
    return null;
  }

  Future<void> cancelMembership(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final name = (row['memberships'] as Map?)?['name'] ??
        l10n.customerDetailFallbackMembershipName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.customerDetailCancelMembershipTitle),
        content: Text(
          l10n.customerDetailCancelMembershipBody(name as String),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.customerDetailBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.customerDetailCancelMembershipButton),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(customersRepositoryProvider)
          .cancelMembership(row['id'] as String);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailCancelMembershipFailed('$e'))),
        );
      }
    }
  }

  Future<void> renewMembership(Map<String, dynamic> row) async {
    final catalog = _catalogMembership(row['membership_id'] as String?);
    if (catalog == null) return;
    final l10n = AppLocalizations.of(context);
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.customerDetailRenewTitle(catalog['name'] as String)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.customerDetailPriceLabel(
                  formatMinor((catalog['price_minor'] as num).toInt(), currency: currency),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: InputDecoration(labelText: l10n.paymentMethodLabel),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text(l10n.paymentMethodCash)),
                  DropdownMenuItem(value: 'card', child: Text(l10n.paymentMethodCard)),
                  DropdownMenuItem(value: 'transfer', child: Text(l10n.paymentMethodTransfer)),
                ],
                onChanged: (v) => setLocal(() => method = v ?? 'cash'),
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
              child: Text(l10n.customerDetailRenew),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      // renew_membership() extends this same row's ends_at in place
      // (carrying over remaining time) — a genuinely new sale would go
      // through sellMembership()/purchase_membership() above instead.
      await ref.read(customersRepositoryProvider).renewMembership(
        idempotencyKey: const Uuid().v4(),
        customerMembershipId: row['id'] as String,
        method: method,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailRenewMembershipFailed('$e'))),
        );
      }
    }
  }

  Future<void> redeemCoupon() async {
    if (coupon.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    try {
      final data = await ref.read(paymentsRepositoryProvider).redeemCoupon(
        organizationId: organizationId,
        code: coupon.text.trim(),
        customerId: customerId,
      );
      final pct = data['discount_percent'];
      final minor = data['discount_minor'];
      final discount = pct != null
          ? l10n.customerDetailCouponOff('$pct')
          : minor != null
          ? l10n.customerDetailCouponAmountOff(formatMinor((minor as num).toInt(), currency: currency))
          : l10n.customerDetailCouponApplied;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailCouponRedeemed(discount))),
        );
      }
      coupon.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerDetailRedeemCouponFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final l10n = AppLocalizations.of(context);
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
                              c.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text('${c.phone ?? ''} • ${c.email ?? ''}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _stat(
                            l10n.customerDetailTotalSpent,
                            formatMinor(c.totalSpentMinor, currency: currency),
                          ),
                          _stat(l10n.reportsNoShows, '${c.noShowCount}'),
                          _stat(
                            l10n.customerDetailLastVisit,
                            c.lastVisitAt == null
                                ? l10n.customerDetailNever
                                : c.lastVisitAt!
                                      .toLocal()
                                      .toString()
                                      .substring(0, 10),
                          ),
                          _stat(l10n.customerDetailLoyaltyPointsLabel, '$points'),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        l10n.privateNotesLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: l10n.privateNotesHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        // AlignmentDirectional so this mirrors correctly in
                        // Arabic (RTL) instead of always pinning to the
                        // geometric right.
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: savingNotes ? null : saveNotes,
                          child: Text(l10n.customerDetailSaveNotesButton),
                        ),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.customerDetailLoyaltyHeading,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canTransact && points > 0)
                            TextButton(
                              onPressed: redeemPoints,
                              child: Text(l10n.customerDetailRedeemPointsButton),
                            ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.customerDetailPackagesHeading,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canTransact && catalogPackages.isNotEmpty)
                            TextButton(
                              onPressed: sellPackage,
                              child: Text(l10n.customerDetailSellPackageButton),
                            ),
                        ],
                      ),
                      if (packages.isEmpty) Text(l10n.customerDetailNoPackages),
                      ...packages.map(
                        (p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            (p['packages'] as Map?)?['name'] ??
                                l10n.customerDetailFallbackPackageName,
                          ),
                          subtitle: Text(
                            l10n.customerDetailPackageUsesLeftStatus(
                                  '${p['remaining_uses']}',
                                  humanStatusLabel(l10n, p['status'] as String? ?? ''),
                                ) +
                                (p['expires_at'] != null
                                    ? ' • ${l10n.customerDetailExpiresOn(DateTime.parse(p['expires_at']).toLocal().toString().substring(0, 10))}'
                                    : ''),
                          ),
                          trailing:
                              canTransact &&
                                  p['status'] == 'active' &&
                                  (p['remaining_uses'] as num? ?? 0) > 0
                              ? TextButton(
                                  onPressed: () => redeemPackageUse(p),
                                  child: Text(l10n.customerDetailUseOne),
                                )
                              : null,
                        ),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.customerDetailMembershipsHeading,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canTransact && catalogMemberships.isNotEmpty)
                            TextButton(
                              onPressed: sellMembership,
                              child: Text(l10n.customerDetailSellMembershipButton),
                            ),
                        ],
                      ),
                      if (memberships.isEmpty)
                        Text(l10n.customerDetailNoMemberships),
                      ...memberships.map((m) {
                        // This schema has no distinct "expired" status —
                        // status is only ever 'active' or 'cancelled'
                        // (renew_membership() refuses to touch a
                        // cancelled row); an active-but-past-ends_at row
                        // is still 'active'. So Renew (early or lapsed)
                        // is offered on any non-cancelled row with a
                        // matching active catalog entry, alongside
                        // Cancel.
                        final cancelled = m['status'] == 'cancelled';
                        final renewable =
                            !cancelled && _catalogMembership(m['membership_id'] as String?) != null;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            (m['memberships'] as Map?)?['name'] ??
                                l10n.customerDetailFallbackMembershipName,
                          ),
                          subtitle: Text(
                            l10n.customerDetailMembershipStatusUntil(
                              humanStatusLabel(l10n, m['status'] as String? ?? ''),
                              DateTime.parse(m['ends_at']).toLocal().toString().substring(0, 10),
                            ),
                          ),
                          trailing: !canTransact || cancelled
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (renewable)
                                      TextButton(
                                        onPressed: () => renewMembership(m),
                                        child: Text(l10n.customerDetailRenew),
                                      ),
                                    TextButton(
                                      onPressed: () => cancelMembership(m),
                                      child: Text(l10n.commonCancel),
                                    ),
                                  ],
                                ),
                        );
                      }),
                      if (canTransact) ...[
                        const Divider(height: 32),
                        Text(
                          l10n.customerDetailCouponHeading,
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
                                decoration: InputDecoration(
                                  hintText: l10n.customerDetailCouponCodeHint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: redeemCoupon,
                              child: Text(l10n.customerDetailRedeem),
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
