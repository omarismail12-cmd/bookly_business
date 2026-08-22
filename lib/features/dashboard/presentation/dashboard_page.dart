import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/security/org_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters/currency.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final org = await ref.read(activeOrganizationProvider.future);
    if (org == null) return;
    final now = DateTime.now();
    final d = await Supabase.instance.client.rpc(
      'report_dashboard',
      params: {
        'p_org': org,
        'p_from': DateTime(
          now.year,
          now.month,
          now.day,
        ).toUtc().toIso8601String(),
        'p_to': DateTime(
          now.year,
          now.month,
          now.day + 1,
        ).toUtc().toIso8601String(),
      },
    );
    if (mounted) {
      setState(() {
        data = Map<String, dynamic>.from(d);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final d = data ?? {};
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Today • ${DateFormat.yMMMd().format(DateTime.now())}',
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _card(
                'Appointments',
                '${d['appointments'] ?? 0}',
                Icons.calendar_month,
              ),
              _card('Completed', '${d['completed'] ?? 0}', Icons.check_circle),
              _card('No-shows', '${d['no_show'] ?? 0}', Icons.warning),
              _card(
                'Revenue',
                formatMinor((d['revenue_minor'] as num?)?.toInt() ?? 0),
                Icons.payments,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Use Calendar for day/week operations, Queue for walk-ins, and CRM for loyalty, packages and campaigns.',
              ),
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
