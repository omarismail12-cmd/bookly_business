import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/widgets/async_state.dart';

/// Appointments for the signed-in customer, across every business they've
/// booked with — enabled by customers.profile_id + the
/// appointments_self_select RLS policy (0013_customer_portal.sql), not by
/// organization membership (a customer never is one).
class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  Object? error;

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
      final result = await Supabase.instance.client
          .from('appointments')
          .select(
            '*,organizations(name,currency),staff(display_name),appointment_services(*,services(name))',
          )
          .order('starts_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(result);
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

  Future<void> openDetail(Map<String, dynamic> row) {
    final start = DateTime.parse(row['starts_at']).toLocal();
    final org = (row['organizations'] as Map?)?['name'] as String?;
    final currency = (row['organizations'] as Map?)?['currency'] as String? ?? 'USD';
    final staff = (row['staff'] as Map?)?['display_name'] as String?;
    final services = List<Map<String, dynamic>>.from(
      row['appointment_services'] ?? [],
    ).map((s) => (s['services'] as Map?)?['name']).whereType<String>().toList();
    final depositRequired = (row['deposit_required_minor'] as num?)?.toInt() ?? 0;
    final depositPaid = (row['deposit_paid_minor'] as num?)?.toInt() ?? 0;
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(org?.isNotEmpty == true ? org! : 'Appointment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 8),
              Text('Status: ${row['status']}'),
              if (staff != null && staff.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Staff: $staff'),
              ],
              if (services.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Services: ${services.join(', ')}'),
              ],
              if (depositRequired > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Deposit: ${formatMinor(depositPaid, currency: currency)} of '
                  '${formatMinor(depositRequired, currency: currency)} paid',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return AsyncErrorView(error: error!, onRetry: load);
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: rows.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyState(message: l10n.myAppointmentsEmpty),
                ),
              ]
            : rows.map((row) {
                final start = DateTime.parse(row['starts_at']).toLocal();
                final org = (row['organizations'] as Map?)?['name'] ?? '';
                final staff = (row['staff'] as Map?)?['display_name'] ?? '';
                final services = List<Map<String, dynamic>>.from(
                  row['appointment_services'] ?? [],
                )
                    .map((s) => (s['services'] as Map?)?['name'])
                    .whereType<String>()
                    .join(', ');
                return Card(
                  child: ListTile(
                    onTap: () => openDetail(row),
                    title: Text(org),
                    subtitle: Text(
                      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} • $staff'
                      '${services.isNotEmpty ? ' • $services' : ''}',
                    ),
                    trailing: Chip(label: Text('${row['status']}')),
                  ),
                );
              }).toList(),
      ),
    );
  }
}
