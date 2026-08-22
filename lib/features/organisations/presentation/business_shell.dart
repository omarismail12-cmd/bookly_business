import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../reports/presentation/reports_page.dart';
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
      membership = await ProviderScopeContainer.readMembership();
    } catch (_) {
      membership = null;
    }
    if (mounted) setState(() => loading = false);
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
    items = [
      _NavItem(
        'Dashboard',
        Icons.dashboard_outlined,
        const DashboardPage(),
        (_) => true,
      ),
      _NavItem(
        'Calendar',
        Icons.calendar_month_outlined,
        const CalendarPage(),
        (_) => true,
      ),
      _NavItem(
        'Queue',
        Icons.people_outline,
        const QueuePage(),
        (r) => r != AppRole.staff,
      ),
      _NavItem(
        'Customers',
        Icons.person_outline,
        const CustomersPage(),
        (_) => true,
      ),
      _NavItem(
        'Services',
        Icons.cut,
        const ServicesPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        'Staff',
        Icons.badge_outlined,
        const StaffPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        'Payments',
        Icons.payments_outlined,
        const PaymentsPage(),
        (r) =>
            r == AppRole.owner ||
            r == AppRole.manager ||
            r == AppRole.receptionist,
      ),
      _NavItem(
        'CRM',
        Icons.card_giftcard,
        const CrmPage(),
        (r) => r == AppRole.owner || r == AppRole.manager,
      ),
      _NavItem(
        'Reports',
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
          body: Row(
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

class ProviderScopeContainer {
  static Future<OrganizationMembership?> readMembership() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await Supabase.instance.client
        .from('organization_members')
        .select('organization_id,role,organizations(id,name,timezone,status)')
        .eq('user_id', uid)
        .eq('status', 'active')
        .limit(1);
    if (rows.isEmpty) return null;
    final r = Map<String, dynamic>.from(rows.first);
    final o = Map<String, dynamic>.from(r['organizations'] as Map);
    if ((o['status'] ?? 'active') != 'active') return null;
    return OrganizationMembership(
      organizationId: r['organization_id'],
      organizationName: o['name'] ?? 'Bookly Business',
      timezone: o['timezone'] ?? 'UTC',
      role: r['role'] ?? 'staff',
    );
  }
}
