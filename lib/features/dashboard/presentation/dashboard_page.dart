import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/report_dashboard.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  ReportDashboard? data;
  bool loading = true;
  String currency = 'USD';
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final org = await ref.read(activeOrganizationProvider.future);
    if (org == null) return;
    currency = await ref.read(activeCurrencyProvider.future);
    final now = DateTime.now();
    final d = await ref.read(reportsRepositoryProvider).dashboard(
      organizationId: org,
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day + 1),
    );
    if (mounted) {
      setState(() {
        data = d;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SkeletonBox(width: 220, height: 28),
          SizedBox(height: 20),
          SkeletonStatRow(count: 4),
          SizedBox(height: 24),
          SkeletonCard(leadingCircle: false, height: 76),
        ],
      );
    }
    final d = data!;
    final l10n = AppLocalizations.of(c);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.dashboardGreetingDate(DateFormat.yMMMd().format(DateTime.now())),
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _card(l10n.dashboardCardAppointments, '${d.appointments}', Icons.calendar_month),
              _card(l10n.dashboardCardCompleted, '${d.completed}', Icons.check_circle),
              _card(l10n.dashboardCardNoShows, '${d.noShow}', Icons.warning),
              _card(
                l10n.dashboardCardRevenue,
                formatMinor(d.revenueMinor, currency: currency),
                Icons.payments,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(l10n.dashboardHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String t, String v, IconData i) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(i)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t),
                Text(
                  v,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
