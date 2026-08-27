import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/async_state.dart';
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
  Object? error;
  String currency = 'USD';
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final org = await ref.read(activeOrganizationProvider.future);
      if (org == null) throw Exception('No active business found.');
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
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
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
    if (error != null) {
      return AsyncErrorView(error: error!, onRetry: load);
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
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              const minTileWidth = 140.0;
              final columns = ((constraints.maxWidth + spacing) /
                      (minTileWidth + spacing))
                  .floor()
                  .clamp(1, 4);
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _card(l10n.dashboardCardAppointments, '${d.appointments}', Icons.calendar_month, tileWidth),
                  _card(l10n.dashboardCardCompleted, '${d.completed}', Icons.check_circle, tileWidth),
                  _card(l10n.dashboardCardNoShows, '${d.noShow}', Icons.warning, tileWidth),
                  _card(
                    l10n.dashboardCardRevenue,
                    formatMinor(d.revenueMinor, currency: currency),
                    Icons.payments,
                    tileWidth,
                  ),
                ],
              );
            },
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

  Widget _card(String t, String v, IconData i, double width) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(i)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
            ),
          ],
        ),
      ),
    ),
  );
}
