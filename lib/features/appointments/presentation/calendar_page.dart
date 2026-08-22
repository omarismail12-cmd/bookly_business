import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/org_context.dart';
import '../../../shared/formatters/currency.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime day = DateTime.now();
  bool week = false, loading = true;
  List<Map<String, dynamic>> rows = [];
  RealtimeChannel? channel;
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
    channel = Supabase.instance.client
        .channel('calendar-$org')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'organization_id',
            value: org,
          ),
          callback: (_) => load(),
        )
        .subscribe();
  }

  Future<void> load() async {
    final o = await ref.read(activeOrganizationProvider.future);
    if (o == null) return;
    final start = DateTime(day.year, day.month, day.day);
    final from = week
        ? start.subtract(Duration(days: start.weekday - 1))
        : start;
    final to = week
        ? from.add(const Duration(days: 7))
        : start.add(const Duration(days: 1));
    final result = await Supabase.instance.client
        .from('appointments')
        .select(
          '*,customers(name,phone),staff(display_name),appointment_services(*,services(name))',
        )
        .eq('organization_id', o)
        .gte('starts_at', from.toUtc().toIso8601String())
        .lt('starts_at', to.toUtc().toIso8601String())
        .order('starts_at');
    if (channel == null) await subscribe(o);
    if (mounted)
      setState(() {
        rows = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
  }

  Future<void> setStatus(String id, String value) async {
    try {
      await Supabase.instance.client.rpc(
        'change_appointment_status',
        params: {'p_appointment': id, 'p_status': value},
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status update failed: $e')));
    }
  }

  /// Cancellation goes through the dedicated cancel_appointment() RPC (not
  /// change_appointment_status) so the service's cancellation window is
  /// actually enforced server-side.
  Future<void> cancel(String id) async {
    try {
      await Supabase.instance.client.rpc(
        'cancel_appointment',
        params: {'p_appointment': id},
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cancellation failed: $e')));
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
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (t == null) return;
    final value = DateTime(
      d.year,
      d.month,
      d.day,
      t.hour,
      t.minute,
    ).toUtc().toIso8601String();
    try {
      await Supabase.instance.client.rpc(
        'reschedule_appointment',
        params: {'p_appointment': id, 'p_new_start': value},
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reschedule failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
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
                onPressed: () {
                  setState(
                    () => day = day.subtract(Duration(days: week ? 7 : 1)),
                  );
                  load();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                week
                    ? 'Week of ${from.year}-${from.month}-${from.day}'
                    : '${day.year}-${day.month}-${day.day}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => day = day.add(Duration(days: week ? 7 : 1)));
                  load();
                },
                icon: const Icon(Icons.chevron_right),
              ),
              FilterChip(
                label: const Text('Week view'),
                selected: week,
                onSelected: (v) {
                  setState(() => week = v);
                  load();
                },
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() => day = DateTime.now());
                  load();
                },
                child: const Text('Today'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: rows.isEmpty
                  ? [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No appointments for this period.'),
                          ),
                        ),
                      ),
                    ]
                  : rows.map((row) {
                      final customer =
                          (row['customers'] as Map?)?['name'] ?? 'Customer';
                      final staff =
                          (row['staff'] as Map?)?['display_name'] ?? 'Staff';
                      final start = DateTime.parse(row['starts_at']).toLocal();
                      final statusLabel = row['status'] ?? '';
                      final depositDue =
                          ((row['deposit_required_minor'] as num?) ?? 0) -
                          ((row['deposit_paid_minor'] as num?) ?? 0);
                      return Card(
                        child: ListTile(
                          title: Text(customer),
                          subtitle: Text(
                            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} • $staff • $statusLabel'
                            '${depositDue > 0 ? ' • deposit due ${formatMinor(depositDue.toInt())}' : ''}',
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
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'checked_in',
                                child: Text('Check in'),
                              ),
                              PopupMenuItem(
                                value: 'in_service',
                                child: Text('Start service'),
                              ),
                              PopupMenuItem(
                                value: 'completed',
                                child: Text('Complete'),
                              ),
                              PopupMenuItem(
                                value: 'no_show',
                                child: Text('No-show'),
                              ),
                              PopupMenuItem(
                                value: 'cancelled',
                                child: Text('Cancel'),
                              ),
                              PopupMenuItem(
                                value: 'reschedule',
                                child: Text('Reschedule'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
