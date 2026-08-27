import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/gen/app_localizations.dart';
import '../../../core/security/org_context.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/formatters/currency.dart';
import '../../../shared/formatters/status_labels.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/appointments_repository.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

const _pageSize = 20;

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime day = DateTime.now();
  bool week = false, loading = true;
  List<Map<String, dynamic>> rows = [];
  RealtimeChannel? channel;
  String currency = 'USD';
  int page = 0;
  bool hasMore = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    if (channel != null) Supabase.instance.client.removeChannel(channel!);
    super.dispose();
  }

  Future<void> subscribe(String org) async {
    channel = ref.read(appointmentsRepositoryProvider).subscribe(org, load);
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    currency = await ref.read(activeCurrencyProvider.future);
    final start = DateTime(day.year, day.month, day.day);
    final from = week
        ? start.subtract(Duration(days: start.weekday - 1))
        : start;
    final to = week
        ? from.add(const Duration(days: 7))
        : start.add(const Duration(days: 1));
    // AppointmentsRepository.listForRange falls back to the local mirror
    // WorkspaceMirror keeps warm for this org (spec slide 9) when the live
    // fetch fails — read-only, and without the customers/staff/
    // appointment_services joins (the mirror only stores flat rows), so
    // those render with their existing "Customer"/"Staff" fallbacks below.
    final result = await ref
        .read(appointmentsRepositoryProvider)
        .listForRange(organizationId: o, from: from, to: to, page: page);
    if (channel == null) await subscribe(o);
    if (mounted) {
      setState(() {
        rows = result;
        hasMore = rows.length == _pageSize;
        loading = false;
      });
    }
  }

  void goto({DateTime? newDay, bool? newWeek}) {
    setState(() {
      if (newDay != null) day = newDay;
      if (newWeek != null) week = newWeek;
      page = 0;
    });
    load();
  }

  Future<void> setStatus(String id, String value) async {
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .changeStatus(appointmentId: id, status: value);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).calendarStatusUpdateFailed('$e'))),
        );
      }
    }
  }

  /// Cancellation goes through the dedicated cancel_appointment() RPC (not
  /// change_appointment_status) so the service's cancellation window is
  /// actually enforced server-side.
  Future<void> cancel(String id) async {
    try {
      await ref.read(appointmentsRepositoryProvider).cancel(id);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).calendarCancellationFailed('$e'))),
        );
      }
    }
  }

  Future<void> reschedule(String id, DateTime current) async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: current,
    );
    if (d == null) return;
    final t = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (t == null) return;
    final value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .reschedule(appointmentId: id, newStart: value);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).calendarRescheduleFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SkeletonList(
        itemCount: 6,
        itemHeight: 76,
        leadingCircle: false,
        padding: EdgeInsets.all(16),
      );
    }
    final l10n = AppLocalizations.of(context);
    final from = week ? day.subtract(Duration(days: day.weekday - 1)) : day;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              IconButton(
                onPressed: () => goto(
                  newDay: day.subtract(Duration(days: week ? 7 : 1)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                week
                    ? l10n.calendarWeekOf('${from.year}-${from.month}-${from.day}')
                    : '${day.year}-${day.month}-${day.day}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () =>
                    goto(newDay: day.add(Duration(days: week ? 7 : 1))),
                icon: const Icon(Icons.chevron_right),
              ),
              FilterChip(
                label: Text(l10n.calendarWeekView),
                selected: week,
                onSelected: (v) => goto(newWeek: v),
              ),
              OutlinedButton(
                onPressed: () => goto(newDay: DateTime.now()),
                child: Text(l10n.commonToday),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(l10n.calendarNoAppointments),
                      ),
                    ),
                  )
                else
                  ...rows.map((row) {
                      final customer = (row['customers'] as Map?)?['name'] ??
                          l10n.commonCustomerFallback;
                      final staff = (row['staff'] as Map?)?['display_name'] ??
                          l10n.bookingStaff;
                      final start = DateTime.parse(row['starts_at']).toLocal();
                      final statusLabel = humanStatusLabel(l10n, (row['status'] ?? '') as String);
                      final depositDue =
                          ((row['deposit_required_minor'] as num?) ?? 0) -
                          ((row['deposit_paid_minor'] as num?) ?? 0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.listItemSpacing),
                        child: Card(
                        child: ListTile(
                          title: Text(customer),
                          subtitle: Text(
                            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} • $staff • $statusLabel'
                            '${depositDue > 0 ? ' • ${l10n.calendarDepositDue(formatMinor(depositDue.toInt(), currency: currency))}' : ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'reschedule') {
                                reschedule(row['id'], start);
                              } else if (v == 'cancelled') {
                                cancel(row['id']);
                              } else {
                                setStatus(row['id'], v);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'checked_in',
                                child: Text(l10n.apptCheckIn),
                              ),
                              PopupMenuItem(
                                value: 'in_service',
                                child: Text(l10n.apptStartService),
                              ),
                              PopupMenuItem(
                                value: 'completed',
                                child: Text(l10n.apptComplete),
                              ),
                              PopupMenuItem(
                                value: 'no_show',
                                child: Text(l10n.apptNoShow),
                              ),
                              PopupMenuItem(
                                value: 'cancelled',
                                child: Text(l10n.commonCancel),
                              ),
                              PopupMenuItem(
                                value: 'reschedule',
                                child: Text(l10n.apptReschedule),
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    }),
                if (page > 0 || hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: page > 0
                              ? () {
                                  setState(() => page--);
                                  load();
                                }
                              : null,
                          child: Text(l10n.commonPrevious),
                        ),
                        const SizedBox(width: 16),
                        Text(l10n.commonPage(page + 1)),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: hasMore
                              ? () {
                                  setState(() => page++);
                                  load();
                                }
                              : null,
                          child: Text(l10n.commonNext),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
