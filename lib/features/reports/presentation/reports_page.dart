import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/localization/gen/app_localizations.dart';
import '../../../../core/pdf/pdf_document_service.dart';
import '../../../../core/security/org_context.dart';
import '../../../../shared/formatters/currency.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../data/reports_repository.dart';
import '../domain/report_dashboard.dart';

final _pdfService = PdfDocumentService();
const _staffPageSize = 10;

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportDashboard d = ReportDashboard.fromMap(const {});
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
    final r = await ref
        .read(reportsRepositoryProvider)
        .dashboard(organizationId: o, from: from, to: to);
    if (mounted) {
      setState(() {
        d = r;
        businessName = membership?.organizationName ?? businessName;
        currency = membership?.currency ?? currency;
        loading = false;
      });
    }
  }

  Future<void> exportPdf() async {
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(
        await _pdfService.createReport(
          data: {
            'businessName': businessName,
            'period': range == 'week' ? 'This week' : 'This month',
            'occupancyPercent': d.occupancyPercent,
            'appointments': d.appointments,
            'completed': d.completed,
            'noShow': d.noShow,
            'revenue': formatMinor(d.revenueMinor, currency: currency),
            'staffPerformance': d.staffPerformance
                .map(
                  (s) => {
                    'display_name': s.displayName,
                    'completed': s.completed,
                    'no_show': s.noShow,
                    'revenue': formatMinor(
                      s.revenueMinor,
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
    final staffPerformance = d.staffPerformance;
    final customerMetrics = d.customerMetrics;
    final campaignMetrics = d.campaignMetrics;
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
          _row('Occupancy', '${d.occupancyPercent}%'),
          _row('Appointments', d.appointments),
          _row('Completed', d.completed),
          _row('Cancelled', d.cancelled),
          _row('No-shows', d.noShow),
          _row(
            'Revenue',
            formatMinor(d.revenueMinor, currency: currency),
          ),
          const SizedBox(height: 24),
          Text('Customers', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('New customers', d.customers),
          _row('Repeat customers', customerMetrics.repeatCustomers),
          _row(
            'Average spend',
            formatMinor(customerMetrics.avgSpendMinor, currency: currency),
          ),
          const SizedBox(height: 24),
          Text('Campaigns', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Campaigns sent', campaignMetrics.campaignsSent),
          _row('Recipients', campaignMetrics.recipients),
          _row('Opened', campaignMetrics.opened),
          _row('Booked', campaignMetrics.booked),
          const SizedBox(height: 24),
          Text('Staff performance', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (staffPerformance.isEmpty) const Text('No staff yet.'),
          ...staffPerformance
              .take((staffPage + 1) * _staffPageSize)
              .map(
                (s) => Card(
                  child: ListTile(
                    title: Text(s.displayName),
                    subtitle: Text(
                      '${s.completed} completed • ${s.noShow} no-shows',
                    ),
                    trailing: Text(
                      formatMinor(s.revenueMinor, currency: currency),
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
