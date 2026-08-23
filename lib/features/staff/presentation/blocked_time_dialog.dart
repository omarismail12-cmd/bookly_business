import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/staff_schedule_repository.dart';

/// Shared one-off "blocked time" (time off) creation dialog — used by the
/// owner/manager staff schedule editor (StaffSchedulePage) and by staff
/// self-service ("add blocked time for themselves" on their Today view).
/// Returns true if a row was inserted.
Future<bool> showAddBlockedTimeDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String staffId,
}) async {
  DateTime date = DateTime.now();
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Add blocked time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Date: ${DateFormat.yMMMd().format(date)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setLocal(() => date = d);
              },
            ),
            ListTile(
              title: Text('Start: ${start.format(context)}'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: start,
                );
                if (t != null) setLocal(() => start = t);
              },
            ),
            ListTile(
              title: Text('End: ${end.format(context)}'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: end,
                );
                if (t != null) setLocal(() => end = t);
              },
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final startsAt = DateTime(
    date.year,
    date.month,
    date.day,
    start.hour,
    start.minute,
  );
  final endsAt = DateTime(
    date.year,
    date.month,
    date.day,
    end.hour,
    end.minute,
  );
  if (!startsAt.isBefore(endsAt)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be before end time.')),
      );
    }
    return false;
  }
  try {
    await ref.read(staffScheduleRepositoryProvider).addBlockedTime(
      staffId: staffId,
      startsAt: startsAt,
      endsAt: endsAt,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
    );
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add blocked time: $e')),
      );
    }
    return false;
  }
}
