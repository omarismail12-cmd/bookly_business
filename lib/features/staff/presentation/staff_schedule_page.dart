import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/gen/app_localizations.dart';
import '../../../shared/widgets/async_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/staff_schedule_repository.dart';
import '../domain/staff_schedule.dart';
import 'blocked_time_dialog.dart';

/// Reference Sunday (2024-01-07) — used with [DateFormat.EEEE] to get a
/// correctly localized weekday name for `weekday` (0 = Sunday .. 6 =
/// Saturday, matching the DB check constraint) without a separate ARB
/// entry per day.
String _weekdayLabel(int weekday, Locale locale) => DateFormat.EEEE(
  locale.toString(),
).format(DateTime(2024, 1, 7 + weekday));

String _fmtTime(String hhmmss) {
  final parts = hhmmss.split(':');
  final t = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  final now = DateTime.now();
  return DateFormat.jm().format(
    DateTime(now.year, now.month, now.day, t.hour, t.minute),
  );
}

String _timeOfDayToSql(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

/// Full schedule editor for one staff member: recurring weekly working
/// hours (already existed on StaffPage), recurring weekly breaks, and
/// one-off blocked time (time off). All three feed get_available_slots()
/// directly (supabase/migrations/0002, 0008) — writing here is what makes
/// the exclusion actually take effect in booking.
class StaffSchedulePage extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;
  const StaffSchedulePage({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  ConsumerState<StaffSchedulePage> createState() => _StaffSchedulePageState();
}

class _StaffSchedulePageState extends ConsumerState<StaffSchedulePage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  bool loading = true;
  Object? error;
  Map<int, WorkingHours> hoursByWeekday = {};
  Map<int, StaffBreak> breaksByWeekday = {};
  List<BlockedTime> blockedTimes = [];

  @override
  void initState() {
    super.initState();
    tabs.addListener(() {
      if (mounted) setState(() {});
    });
    Future.microtask(load);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = ref.read(staffScheduleRepositoryProvider);
      final hours = await repo.workingHours(widget.staffId);
      final breaks = await repo.staffBreaks(widget.staffId);
      final blocked = await repo.blockedTimes(widget.staffId);
      if (!mounted) return;
      setState(() {
        hoursByWeekday = {for (final r in hours) r.weekday: r};
        breaksByWeekday = {for (final r in breaks) r.weekday: r};
        blockedTimes = blocked;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editWorkingHours(int weekday) async {
    final l10n = AppLocalizations.of(context);
    final weekdayName = _weekdayLabel(weekday, Localizations.localeOf(context));
    final existing = hoursByWeekday[weekday];
    TimeOfDay start = existing != null
        ? _parseTime(existing.startTime)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = existing != null
        ? _parseTime(existing.endTime)
        : const TimeOfDay(hour: 17, minute: 0);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.scheduleWorkingHoursDialogTitle(weekdayName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.scheduleStartLabel(start.format(context))),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: start,
                  );
                  if (t != null) setLocal(() => start = t);
                },
              ),
              ListTile(
                title: Text(l10n.scheduleEndLabel(end.format(context))),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: end,
                  );
                  if (t != null) setLocal(() => end = t);
                },
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(context, 'clear'),
                child: Text(l10n.scheduleRemove),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      final repo = ref.read(staffScheduleRepositoryProvider);
      if (result == 'clear' && existing != null) {
        await repo.deleteWorkingHours(existing.id);
      } else if (result == 'save') {
        if (!(start.hour * 60 + start.minute < end.hour * 60 + end.minute)) {
          throw Exception(l10n.scheduleStartBeforeEnd);
        }
        await repo.upsertWorkingHours(
          staffId: widget.staffId,
          weekday: weekday,
          startTime: _timeOfDayToSql(start),
          endTime: _timeOfDayToSql(end),
        );
      }
      await load();
    } catch (e) {
      _showError(l10n.scheduleSaveWorkingHoursFailed('$e'));
    }
  }

  Future<void> editBreak(int weekday) async {
    final l10n = AppLocalizations.of(context);
    final weekdayName = _weekdayLabel(weekday, Localizations.localeOf(context));
    final existing = breaksByWeekday[weekday];
    TimeOfDay start = existing != null
        ? _parseTime(existing.startTime)
        : const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay end = existing != null
        ? _parseTime(existing.endTime)
        : const TimeOfDay(hour: 14, minute: 0);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.scheduleBreakDialogTitle(weekdayName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.scheduleStartLabel(start.format(context))),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: start,
                  );
                  if (t != null) setLocal(() => start = t);
                },
              ),
              ListTile(
                title: Text(l10n.scheduleEndLabel(end.format(context))),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: end,
                  );
                  if (t != null) setLocal(() => end = t);
                },
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(context, 'clear'),
                child: Text(l10n.scheduleRemove),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      final repo = ref.read(staffScheduleRepositoryProvider);
      if (result == 'clear' && existing != null) {
        await repo.deleteBreak(existing.id);
      } else if (result == 'save') {
        if (!(start.hour * 60 + start.minute < end.hour * 60 + end.minute)) {
          throw Exception(l10n.scheduleStartBeforeEnd);
        }
        await repo.upsertBreak(
          staffId: widget.staffId,
          weekday: weekday,
          startTime: _timeOfDayToSql(start),
          endTime: _timeOfDayToSql(end),
        );
      }
      await load();
    } catch (e) {
      _showError(l10n.scheduleSaveBreakFailed('$e'));
    }
  }

  Future<void> addBlockedTime() async {
    final added = await showAddBlockedTimeDialog(
      context,
      ref: ref,
      staffId: widget.staffId,
    );
    if (added) await load();
  }

  Future<void> deleteBlockedTime(BlockedTime row) async {
    try {
      await ref.read(staffScheduleRepositoryProvider).deleteBlockedTime(row.id);
      await load();
    } catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context).scheduleRemoveBlockedTimeFailed('$e'));
    }
  }

  TimeOfDay _parseTime(String hhmmss) {
    final parts = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scheduleTitle(widget.staffName)),
        bottom: TabBar(
          controller: tabs,
          tabs: [
            Tab(text: l10n.scheduleWorkingHoursTab),
            Tab(text: l10n.scheduleBreaksTab),
            Tab(text: l10n.scheduleBlockedTimeTab),
          ],
        ),
      ),
      floatingActionButton: !loading && tabs.index == 2
          ? FloatingActionButton(
              onPressed: addBlockedTime,
              child: const Icon(Icons.add),
            )
          : null,
      body: loading
          ? const SkeletonList(itemCount: 7, itemHeight: 64)
          : error != null
          ? AsyncErrorView(error: error!, onRetry: load)
          : TabBarView(
              controller: tabs,
              children: [
                _weekdayList<WorkingHours>(
                  byWeekday: hoursByWeekday,
                  startTimeOf: (r) => r.startTime,
                  endTimeOf: (r) => r.endTime,
                  onTap: editWorkingHours,
                  emptyLabel: l10n.scheduleOff,
                ),
                _weekdayList<StaffBreak>(
                  byWeekday: breaksByWeekday,
                  startTimeOf: (r) => r.startTime,
                  endTimeOf: (r) => r.endTime,
                  onTap: editBreak,
                  emptyLabel: l10n.scheduleNoBreak,
                ),
                _blockedTimeList(l10n),
              ],
            ),
    );
  }

  Widget _weekdayList<T>({
    required Map<int, T> byWeekday,
    required String Function(T) startTimeOf,
    required String Function(T) endTimeOf,
    required void Function(int weekday) onTap,
    required String emptyLabel,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, i) {
        final weekday = i; // 0 = Sunday .. 6 = Saturday, matches DB check
        final row = byWeekday[weekday];
        return Card(
          child: ListTile(
            title: Text(_weekdayLabel(weekday, Localizations.localeOf(context))),
            subtitle: Text(
              row == null
                  ? emptyLabel
                  : '${_fmtTime(startTimeOf(row))} – ${_fmtTime(endTimeOf(row))}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTap(weekday),
          ),
        );
      },
    );
  }

  Widget _blockedTimeList(AppLocalizations l10n) {
    if (blockedTimes.isEmpty) {
      return EmptyState(message: l10n.scheduleNoBlockedTime);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: blockedTimes.length,
      itemBuilder: (context, i) {
        final row = blockedTimes[i];
        final start = row.startsAt.toLocal();
        final end = row.endsAt.toLocal();
        return Card(
          child: ListTile(
            title: Text(DateFormat.yMMMd().add_jm().format(start)),
            subtitle: Text(
              '${DateFormat.jm().format(end)}'
              '${row.reason != null ? ' • ${row.reason}' : ''}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => deleteBlockedTime(row),
            ),
          ),
        );
      },
    );
  }
}
