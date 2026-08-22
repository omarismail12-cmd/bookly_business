import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/pdf/pdf_document_service.dart';
import '../../../../core/security/org_context.dart';
import '../../../../shared/formatters/currency.dart';
import '../../../../shared/widgets/skeleton.dart';

final _pdfService = PdfDocumentService();
const _staffPageSize = 10;

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
  String currency = 'USD';
  // report_dashboard() returns the whole staff_performance array in one
  // RPC call (it's an aggregate, not a paginatable table query) — this
  // page then reveals it a page at a time instead of a real range() query.
  int staffPage = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      staffPage = 0;
    });
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
        currency = membership?.currency ?? currency;
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
            'revenue': formatMinor(
              (d['revenue_minor'] as num?)?.toInt() ?? 0,
              currency: currency,
            ),
            'staffPerformance': staffPerformance
                .map(
                  (s) => {
                    'display_name': s['display_name'],
                    'completed': s['completed'],
                    'no_show': s['no_show'],
                    'revenue': formatMinor(
                      (s['revenue_minor'] as num? ?? 0).toInt(),
                      currency: currency,
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
    if (loading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SkeletonBox(width: 180, height: 28),
          SizedBox(height: 20),
          SkeletonStatRow(count: 3),
          SizedBox(height: 24),
          SkeletonCard(leadingCircle: false, height: 76),
          SizedBox(height: 12),
          SkeletonCard(leadingCircle: false, height: 76),
        ],
      );
    }
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
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                AppLocalizations.of(c).pageTitleReports,
                style: Theme.of(c).textTheme.headlineSmall,
              );
              final exportButton = IconButton(
                tooltip: 'Export PDF',
                onPressed: exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              );
              final rangeSelector = SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('This week')),
                  ButtonSegment(value: 'month', label: Text('This month')),
                ],
                selected: {range},
                onSelectionChanged: (v) {
                  setState(() => range = v.first);
                  load();
                },
              );
              // SegmentedButton doesn't shrink like Expanded/Text does — on
              // a narrow phone, title + export icon + both segments can
              // exceed the available width and overflow the Row. Stack
              // instead of squeezing below the breakpoint.
              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        exportButton,
                      ],
                    ),
                    const SizedBox(height: 12),
                    rangeSelector,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  exportButton,
                  const SizedBox(width: 8),
                  rangeSelector,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Occupancy & volume', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Occupancy', '${d['occupancy_percent'] ?? 0}%'),
          _row('Appointments', d['appointments']),
          _row('Completed', d['completed']),
          _row('Cancelled', d['cancelled']),
          _row('No-shows', d['no_show']),
          _row(
            'Revenue',
            formatMinor(
              (d['revenue_minor'] as num?)?.toInt() ?? 0,
              currency: currency,
            ),
          ),
          const SizedBox(height: 24),
          Text('Customers', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('New customers', d['customers']),
          _row('Repeat customers', customerMetrics['repeat_customers']),
          _row(
            'Average spend',
            formatMinor(
              (customerMetrics['avg_spend_minor'] as num?)?.toInt() ?? 0,
              currency: currency,
            ),
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
          ...staffPerformance
              .take((staffPage + 1) * _staffPageSize)
              .map(
                (s) => Card(
                  child: ListTile(
                    title: Text(s['display_name'] ?? ''),
                    subtitle: Text(
                      '${s['completed']} completed • ${s['no_show']} no-shows',
                    ),
                    trailing: Text(
                      formatMinor(
                        (s['revenue_minor'] as num? ?? 0).toInt(),
                        currency: currency,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          if (staffPerformance.length > (staffPage + 1) * _staffPageSize)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => staffPage++),
                  child: const Text('Load more'),
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
