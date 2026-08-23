import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/analytics/firebase_crash_reporting.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/notifications/firebase_notification_service.dart';
import '../../../core/permissions/app_role.dart';
import '../../../core/security/org_context.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../appointments/presentation/calendar_page.dart';
import '../../queue/presentation/queue_page.dart';
import '../../customers/presentation/customers_page.dart';
import '../../services/presentation/services_page.dart';
import '../../staff/presentation/staff_page.dart';
import '../../payments/presentation/payments_page.dart';
import '../../customers/loyalty/crm_page.dart';
import '../../packages/presentation/offers_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../locations/presentation/locations_page.dart';
import '../../staff_portal/presentation/staff_today_page.dart';
import '../../../shared/widgets/sync_status_banner.dart';
import 'organization_setup_page.dart';

class BusinessShell extends StatefulWidget {
  const BusinessShell({super.key});
  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  final bool Function(AppRole) allowed;
  const _NavItem(this.label, this.icon, this.page, this.allowed);
}

class _BusinessShellState extends State<BusinessShell> {
  int index = 0;
  OrganizationMembership? membership;
  bool loading = true;
  bool suspended = false;
  late List<_NavItem> items;
  final _notifications = FirebaseNotificationService();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final all = await Supabase.instance.client.rpc('get_my_memberships');
      final rows = List<Map<String, dynamic>>.from(all);
      suspended = rows.any((x) => x['status'] == 'suspended');
      membership = await fetchActiveMembership();
    } catch (_) {
      membership = null;
    }
    if (mounted) setState(() => loading = false);
    final m = membership;
    if (m != null) {
      // Best-effort push registration. FirebaseNotificationService is a
      // safe no-op until a real Firebase project is configured for this
      // platform (see its class doc).
      _registerForPush(m.organizationId);
      final uid = Supabase.instance.client.auth.currentUser?.id;
      crashReporting.setUser(uid);
    }
  }

  Future<void> _registerForPush(String organizationId) async {
    try {
      await _notifications.initialize();
      await _notifications.requestPermission();
      await _notifications.subscribeToOrganization(organizationId);
    } catch (_) {
      // Never let push registration block or crash the business shell.
    }
  }

  Future<void> logout() => Supabase.instance.client.auth.signOut();

  Future<void> openMoreSheet(List<_NavItem> overflow, int firstIndex) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.navMore,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (int i = 0; i < overflow.length; i++)
              ListTile(
                leading: Icon(overflow[i].icon),
                title: Text(overflow[i].label),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => index = firstIndex + i);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (membership == null) {
      if (suspended) {
        return const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Your Bookly business membership is suspended. Contact the business owner before creating or accessing another workspace.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      return OrganizationSetupPage(onCreated: load);
    }
    final role = AppRole.values.byName(membership!.role);
    final l10n = AppLocalizations.of(context);
    items = [
      _NavItem(
        l10n.staffPortalTitle,
        Icons.today_outlined,
        const StaffTodayPage(),
        (r) => r == AppRole.staff,
      ),
      _NavItem(
        l10n.navDashboard,
        Icons.dashboard_outlined,
        const DashboardPage(),
        (_) => true,
      ),
      _NavItem(
        l10n.navCalendar,
        Icons.calendar_month_outlined,
        const CalendarPage(),
        (_) => true,
      ),
      _NavItem(
        l10n.navQueue,
        Icons.people_outline,
        const QueuePage(),
        (r) => r != AppRole.staff,
      ),
      _NavItem(
        l10n.navCustomers,
        Icons.person_outline,
        const CustomersPage(),
        (_) => true,
      ),
      _NavItem(
        l10n.navServices,
        Icons.cut,
        const ServicesPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        l10n.navLocations,
        Icons.storefront_outlined,
        const LocationsPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        l10n.navStaff,
        Icons.badge_outlined,
        const StaffPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        l10n.navPayments,
        Icons.payments_outlined,
        const PaymentsPage(),
        (r) =>
            r == AppRole.owner ||
            r == AppRole.manager ||
            r == AppRole.receptionist,
      ),
      _NavItem(
        l10n.navCrm,
        Icons.card_giftcard,
        const CrmPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        l10n.navOffers,
        Icons.local_offer_outlined,
        const OffersPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        l10n.navReports,
        Icons.bar_chart,
        const ReportsPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
    ].where((x) => x.allowed(role)).toList();
    if (index >= items.length) index = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: Text(membership!.organizationName),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(role.name)),
              ),
              IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
            ],
          ),
          body: Column(
            children: [
              const SyncStatusBanner(),
              Expanded(
                child: Row(
                  children: [
                    if (wide)
                      NavigationRail(
                        selectedIndex: index,
                        onDestinationSelected: (v) => setState(() => index = v),
                        labelType: NavigationRailLabelType.all,
                        destinations: items
                            .map(
                              (x) => NavigationRailDestination(
                                icon: Icon(x.icon),
                                selectedIcon: Icon(x.icon),
                                label: Text(x.label),
                              ),
                            )
                            .toList(),
                      ),
                    Expanded(child: items[index].page),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide ? null : _buildBottomNav(l10n),
        );
      },
    );
  }

  /// Mobile bottom nav: the first 4 sections get their own tab; anything
  /// beyond that collapses into a 5th "More" tab that opens a bottom sheet
  /// listing the rest — instead of hiding them behind an AppBar popup menu
  /// with no persistent affordance.
  Widget _buildBottomNav(AppLocalizations l10n) {
    final needsMore = items.length > 5;
    final visible = needsMore ? items.take(4).toList() : items;
    final overflow = needsMore ? items.skip(4).toList() : const <_NavItem>[];
    final selected = !needsMore
        ? index
        : (index < 4 ? index : 4);
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (v) {
        if (v < visible.length) {
          setState(() => index = v);
        } else {
          openMoreSheet(overflow, 4);
        }
      },
      destinations: [
        for (final x in visible)
          NavigationDestination(
            icon: Icon(x.icon),
            selectedIcon: Icon(x.icon),
            label: x.label,
          ),
        if (needsMore)
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: const Icon(Icons.more_horiz),
            label: l10n.navMore,
          ),
      ],
    );
  }
}
