import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/formatters/status_labels.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../staff/presentation/blocked_time_dialog.dart';
import 'staff_appointment_detail_page.dart';

/// The staff member's own landing view: today's appointments only, with
/// large touch targets and one-tap status advances (check-in / start
/// service / complete). This is the default (and, per Permission.
/// manageCalendar, only) tab for AppRole.staff in BusinessShell — the
/// full org Calendar is no longer reachable for staff, matching
/// appointments_select RLS (0042_staff_scoping_hardening.sql), which
/// scopes a staff member's read access to their own appointments only.
class StaffTodayPage extends ConsumerStatefulWidget {
  const StaffTodayPage({super.key});

  @override
  ConsumerState<StaffTodayPage> createState() => _StaffTodayPageState();
}

class _StaffTodayPageState extends ConsumerState<StaffTodayPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  Object? error;
  String? staffId;
  List<Map<String, dynamic>> rows = [];

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
      final o = await ref.read(activeOrganizationProvider.future);
      final uid = supabase.auth.currentUser?.id;
      if (o == null || uid == null) return;
      final staffRow = await supabase
          .from('staff')
          .select('id')
          .eq('organization_id', o)
          .eq('profile_id', uid)
          .maybeSingle();
      staffId = staffRow?['id'] as String?;
      if (staffId == null) {
        if (mounted) setState(() => rows = []);
        return;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final result = await supabase
          .from('appointments')
          .select(
            '*,customers(name,phone,email),appointment_services(*,services(name))',
          )
          .eq('staff_id', staffId as String)
          .gte('starts_at', start.toUtc().toIso8601String())
          .lt('starts_at', end.toUtc().toIso8601String())
          .isFilter('deleted_at', null)
          .order('starts_at');
      if (mounted) {
        setState(() => rows = List<Map<String, dynamic>>.from(result));
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> advance(String appointmentId, String status) async {
    try {
      await supabase.rpc(
        'change_appointment_status',
        params: {'p_appointment': appointmentId, 'p_status': status},
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).staffTodayStatusUpdateFailed('$e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> openDetail(Map<String, dynamic> row) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffAppointmentDetailPage(appointment: row),
      ),
    );
    load();
  }

  Future<void> addOwnBlockedTime() async {
    final id = staffId;
    if (id == null) return;
    final added = await showAddBlockedTimeDialog(context, ref: ref, staffId: id);
    if (added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).staffTimeOffAdded)),
      );
    }
  }

  ({String label, String next})? _primaryAction(AppLocalizations l10n, String status) {
    switch (status) {
      case 'pending':
      case 'confirmed':
        return (label: l10n.apptCheckIn, next: 'checked_in');
      case 'checked_in':
        return (label: l10n.apptStartService, next: 'in_service');
      case 'in_service':
        return (label: l10n.apptComplete, next: 'completed');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.staffPortalTitle} • ${DateFormat.MMMEd().format(DateTime.now())}',
        ),
        actions: [
          IconButton(
            tooltip: l10n.blockedTimeAdd,
            onPressed: staffId == null ? null : addOwnBlockedTime,
            icon: const Icon(Icons.event_busy_outlined),
          ),
        ],
      ),
      body: loading
          ? const SkeletonList(itemCount: 4, itemHeight: 100)
          : error != null
          ? AsyncErrorView(error: error!, onRetry: load)
          : staffId == null
          ? EmptyState(message: l10n.staffTodayNoProfile)
          : RefreshIndicator(
              onRefresh: load,
              child: rows.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 96),
                          child: EmptyState(message: l10n.staffPortalEmpty),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        final customer = (row['customers'] as Map?)?['name'] ??
                            l10n.commonCustomerFallback;
                        final services = List<Map<String, dynamic>>.from(
                          row['appointment_services'] ?? [],
                        )
                            .map((s) => (s['services'] as Map?)?['name'])
                            .whereType<String>()
                            .join(', ');
                        final start = DateTime.parse(
                          row['starts_at'],
                        ).toLocal();
                        final status = row['status'] as String;
                        final action = _primaryAction(l10n, status);
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => openDetail(row),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat.jm().format(start),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          customer,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      _StatusChip(status: status),
                                    ],
                                  ),
                                  if (services.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      services,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                  if (action != null) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: FilledButton(
                                        onPressed: () =>
                                            advance(row['id'], action.next),
                                        child: Text(action.label),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() => switch (status) {
    'completed' => AppTheme.success,
    'cancelled' || 'no_show' => AppTheme.danger,
    'in_service' || 'checked_in' => AppTheme.warning,
    _ => AppTheme.primary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        humanStatusLabel(AppLocalizations.of(context), status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
