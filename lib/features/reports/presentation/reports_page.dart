import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/pdf/pdf_document_service.dart';
import '../../../../core/security/org_context.dart';
import '../../../../shared/formatters/currency.dart';

final _pdfService = PdfDocumentService();

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  Map<String, dynamic> d = {};
  bool loading = true;
  String range = 'month';
  String businessName = 'Bookly Business';

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() => loading = true);
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    final membership = await ref.read(activeMembershipProvider.future);
    final now = DateTime.now();
    final from = range == 'week'
        ? now.subtract(Duration(days: now.weekday - 1))
        : DateTime(now.year, now.month, 1);
    final to = range == 'week'
        ? from.add(const Duration(days: 7))
        : DateTime(now.year, now.month + 1, 1);
    final r = await Supabase.instance.client.rpc(
      'report_dashboard',
      params: {
        'p_org': o,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    if (mounted) {
      setState(() {
        d = Map<String, dynamic>.from(r);
        businessName = membership?.organizationName ?? businessName;
        loading = false;
      });
    }
  }

  Future<void> exportPdf() async {
    final staffPerformance = List<Map<String, dynamic>>.from(
      d['staff_performance'] ?? [],
    );
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(
        await _pdfService.createReport(
          data: {
            'businessName': businessName,
            'period': range == 'week' ? 'This week' : 'This month',
            'occupancyPercent': d['occupancy_percent'] ?? 0,
            'appointments': d['appointments'] ?? 0,
            'completed': d['completed'] ?? 0,
            'noShow': d['no_show'] ?? 0,
            'revenue': formatMinor((d['revenue_minor'] as num?)?.toInt() ?? 0),
            'staffPerformance': staffPerformance
                .map(
                  (s) => {
                    'display_name': s['display_name'],
                    'completed': s['completed'],
                    'no_show': s['no_show'],
                    'revenue': formatMinor(
                      (s['revenue_minor'] as num? ?? 0).toInt(),
                    ),
                  },
                )
                .toList(),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final staffPerformance = List<Map<String, dynamic>>.from(
      d['staff_performance'] ?? [],
    );
    final customerMetrics = Map<String, dynamic>.from(
      d['customer_metrics'] ?? {},
    );
    final campaignMetrics = Map<String, dynamic>.from(
      d['campaign_metrics'] ?? {},
    );
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(c).pageTitleReports,
                  style: Theme.of(c).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Export PDF',
                onPressed: exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('This week')),
                  ButtonSegment(value: 'month', label: Text('This month')),
                ],
                selected: {range},
                onSelectionChanged: (v) {
                  setState(() => range = v.first);
                  load();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Occupancy & volume', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Occupancy', '${d['occupancy_percent'] ?? 0}%'),
          _row('Appointments', d['appointments']),
          _row('Completed', d['completed']),
          _row('Cancelled', d['cancelled']),
          _row('No-shows', d['no_show']),
          _row('Revenue', formatMinor((d['revenue_minor'] as num?)?.toInt() ?? 0)),
          const SizedBox(height: 24),
          Text('Customers', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('New customers', d['customers']),
          _row('Repeat customers', customerMetrics['repeat_customers']),
          _row(
            'Average spend',
            formatMinor((customerMetrics['avg_spend_minor'] as num?)?.toInt() ?? 0),
          ),
          const SizedBox(height: 24),
          Text('Campaigns', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Campaigns sent', campaignMetrics['campaigns_sent']),
          _row('Recipients', campaignMetrics['recipients']),
          _row('Opened', campaignMetrics['opened']),
          _row('Booked', campaignMetrics['booked']),
          const SizedBox(height: 24),
          Text('Staff performance', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (staffPerformance.isEmpty) const Text('No staff yet.'),
          ...staffPerformance.map(
            (s) => Card(
              child: ListTile(
                title: Text(s['display_name'] ?? ''),
                subtitle: Text(
                  '${s['completed']} completed • ${s['no_show']} no-shows',
                ),
                trailing: Text(
                  formatMinor((s['revenue_minor'] as num? ?? 0).toInt()),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String a, Object? b) => Card(
    child: ListTile(
      title: Text(a),
      trailing: Text('${b ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
