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

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (membership == null) {
      if (suspended)
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
      return OrganizationSetupPage(onCreated: load);
    }
    final role = AppRole.values.byName(membership!.role);
    final l10n = AppLocalizations.of(context);
    items = [
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
              if (!wide)
                PopupMenuButton<int>(
                  onSelected: (v) => setState(() => index = v),
                  itemBuilder: (_) => [
                    for (int i = 0; i < items.length; i++)
                      PopupMenuItem(value: i, child: Text(items[i].label)),
                  ],
                ),
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
                        selectedIndex: index < 5 ? index : 0,
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
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index < 5 ? index : 0,
                  onDestinationSelected: (v) => setState(() => index = v),
                  destinations: items
                      .take(5)
                      .map(
                        (x) => NavigationDestination(
                          icon: Icon(x.icon),
                          selectedIcon: Icon(x.icon),
                          label: x.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
