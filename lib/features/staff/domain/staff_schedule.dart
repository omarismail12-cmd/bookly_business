/// Recurring weekly working hours for one staff member on one weekday.
///
/// Mirrors `public.working_hours` exactly (supabase/migrations/0001_foundation.sql).
/// `startTime`/`endTime` are kept as raw "HH:MM:SS" strings — that's the
/// wire format Postgres `time` columns use and the format the presentation
/// layer already parses/formats, so converting to a Dart time type here
/// would be a behavior-risking detour for a pure refactor.
class WorkingHours {
  final String id;
  final String staffId;
  final int weekday;
  final String startTime;
  final String endTime;

  const WorkingHours({
    required this.id,
    required this.staffId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  factory WorkingHours.fromRow(Map<String, dynamic> row) => WorkingHours(
    id: row['id'] as String,
    staffId: row['staff_id'] as String,
    weekday: row['weekday'] as int,
    startTime: row['start_time'] as String,
    endTime: row['end_time'] as String,
  );
}

/// Recurring weekly break for one staff member on one weekday.
///
/// Mirrors `public.staff_breaks` exactly.
class StaffBreak {
  final String id;
  final String staffId;
  final int weekday;
  final String startTime;
  final String endTime;

  const StaffBreak({
    required this.id,
    required this.staffId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  factory StaffBreak.fromRow(Map<String, dynamic> row) => StaffBreak(
    id: row['id'] as String,
    staffId: row['staff_id'] as String,
    weekday: row['weekday'] as int,
    startTime: row['start_time'] as String,
    endTime: row['end_time'] as String,
  );
}

/// A one-off block of unavailable time (time off) for one staff member.
///
/// Mirrors `public.blocked_times` exactly.
class BlockedTime {
  final String id;
  final String staffId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? reason;
  final DateTime createdAt;

  const BlockedTime({
    required this.id,
    required this.staffId,
    required this.startsAt,
    required this.endsAt,
    this.reason,
    required this.createdAt,
  });

  factory BlockedTime.fromRow(Map<String, dynamic> row) => BlockedTime(
    id: row['id'] as String,
    staffId: row['staff_id'] as String,
    startsAt: DateTime.parse(row['starts_at'] as String),
    endsAt: DateTime.parse(row['ends_at'] as String),
    reason: row['reason'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
