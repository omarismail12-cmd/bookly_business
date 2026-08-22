import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/security/org_context.dart';
import '../../../../shared/formatters/currency.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  Map<String, dynamic> d = {};
  bool loading = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toUtc();
    final to = DateTime(now.year, now.month + 1, 1).toUtc();
    final r = await Supabase.instance.client.rpc(
      'report_dashboard',
      params: {
        'p_org': o,
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
      },
    );
    if (mounted) {
      setState(() {
        d = Map<String, dynamic>.from(r);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext c) => loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Reports', style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _row('Appointments', d['appointments']),
            _row('Completed', d['completed']),
            _row('Cancelled', d['cancelled']),
            _row('No-shows', d['no_show']),
            _row(
              'Revenue',
              formatMinor((d['revenue_minor'] as num?)?.toInt() ?? 0),
            ),
          ],
        );
  Widget _row(String a, Object? b) => Card(
    child: ListTile(
      title: Text(a),
      trailing: Text('$b', style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
