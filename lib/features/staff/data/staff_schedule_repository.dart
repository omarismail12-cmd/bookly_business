import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/supabase_provider.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/staff_schedule.dart';

/// Wraps every Supabase call for `working_hours`, `staff_breaks` and
/// `blocked_times` — the three tables that feed `get_available_slots()`
/// (supabase/migrations/0002, 0008) directly. Presentation code must go
/// through this instead of calling `Supabase.instance.client` directly.
///
/// `upsertWorkingHours`/`upsertBreak` are local-first (spec slide 9): they
/// queue through [SyncService] rather than writing straight to Supabase, so
/// editing a schedule works offline. Both tables have no `version` column
/// (see supabase/migrations/0001_foundation.sql) — there is nothing to
/// detect a conflict against, so these stay last-write-wins, unlike the
/// version-checked customer/service edits in SyncService.drain(). Reads,
/// deletes and blocked-time writes are unchanged — the working-hours/breaks
/// list is small enough that a live read failing offline just shows
/// whatever the page already has loaded, and delete/blocked-time editing
/// wasn't part of this phase's scope.
class StaffScheduleRepository {
  final SupabaseClient client;
  final SyncService syncService;
  StaffScheduleRepository(this.client, this.syncService);

  Future<List<WorkingHours>> workingHours(String staffId) async {
    final rows = await client
        .from('working_hours')
        .select()
        .eq('staff_id', staffId);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(WorkingHours.fromRow).toList();
  }

  Future<void> upsertWorkingHours({
    required String staffId,
    required int weekday,
    required String startTime,
    required String endTime,
  }) async {
    await syncService.enqueue(
      SyncOperation(
        operationId: const Uuid().v4(),
        entity: 'working_hours',
        entityId: '$staffId:$weekday',
        operation: 'upsert_working_hours',
        payload: {
          'staff_id': staffId,
          'weekday': weekday,
          'start_time': startTime,
          'end_time': endTime,
        },
      ),
    );
    await syncService.drain();
  }

  Future<void> deleteWorkingHours(String id) =>
      client.from('working_hours').delete().eq('id', id);

  Future<List<StaffBreak>> staffBreaks(String staffId) async {
    final rows = await client
        .from('staff_breaks')
        .select()
        .eq('staff_id', staffId);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(StaffBreak.fromRow).toList();
  }

  Future<void> upsertBreak({
    required String staffId,
    required int weekday,
    required String startTime,
    required String endTime,
  }) async {
    await syncService.enqueue(
      SyncOperation(
        operationId: const Uuid().v4(),
        entity: 'staff_breaks',
        entityId: '$staffId:$weekday',
        operation: 'upsert_staff_break',
        payload: {
          'staff_id': staffId,
          'weekday': weekday,
          'start_time': startTime,
          'end_time': endTime,
        },
      ),
    );
    await syncService.drain();
  }

  Future<void> deleteBreak(String id) =>
      client.from('staff_breaks').delete().eq('id', id);

  Future<List<BlockedTime>> blockedTimes(String staffId) async {
    final rows = await client
        .from('blocked_times')
        .select()
        .eq('staff_id', staffId)
        .order('starts_at');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(BlockedTime.fromRow).toList();
  }

  Future<void> addBlockedTime({
    required String staffId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) => client.from('blocked_times').insert({
    'staff_id': staffId,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'reason': reason,
  });

  Future<void> deleteBlockedTime(String id) =>
      client.from('blocked_times').delete().eq('id', id);
}

final staffScheduleRepositoryProvider = Provider<StaffScheduleRepository>(
  (ref) => StaffScheduleRepository(
    ref.watch(supabaseProvider),
    ref.watch(syncServiceProvider),
  ),
);
