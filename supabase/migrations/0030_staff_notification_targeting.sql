-- Phase 6: staff-side notification targeting.
--
-- queue_appointment_notifications() (0014) has only ever targeted the
-- appointment's customer (recipient_customer_id) — the assigned staff
-- member never got a job at all, despite the spec calling for "booking
-- confirmed -> customer+staff". Separately, reschedule_appointment() (0019)
-- never called any notification function at all: rescheduling silently
-- left the existing reminder_24h/reminder_2h jobs scheduled against the
-- OLD start time, and never queued anything for "booking rescheduled ->
-- customer+staff" either.
--
-- The delivery pipeline already supports staff recipients — device_tokens
-- has always had a user_id column, business_shell.dart's
-- _registerForPush already upserts a device_tokens row keyed by
-- auth.uid() for every signed-in business-side user (owner/manager/
-- receptionist/staff alike), and the notifications-worker already looks
-- tokens up by recipient_user_id when set. Only the RPCs never inserted
-- that row.
--
-- notification_jobs_appointment_kind_unique is (appointment_id, kind) —
-- one row per kind per appointment — so a staff notification for the same
-- logical event needs its own kind, not a second row under 'confirmation'/
-- 'reminder_24h' etc. New kinds only; every existing kind's behavior is
-- unchanged.

create or replace function public.queue_appointment_notifications(p_appointment uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
  v_staff_profile uuid;
begin

  select * into a from public.appointments where id = p_appointment;
  if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  if auth.uid() is not null and not public.has_org_role(a.organization_id, array['owner','manager','receptionist','staff']) then
    raise exception 'FORBIDDEN';
  end if;

  insert into public.notification_jobs(organization_id, appointment_id, recipient_customer_id, kind, scheduled_for)
  values (a.organization_id, a.id, a.customer_id, 'confirmation', now())
  on conflict (appointment_id, kind) where appointment_id is not null do nothing;

  insert into public.notification_jobs(organization_id, appointment_id, recipient_customer_id, kind, scheduled_for)
  values (a.organization_id, a.id, a.customer_id, 'reminder_24h', greatest(now(), a.starts_at - interval '24 hours'))
  on conflict (appointment_id, kind) where appointment_id is not null
  do update set scheduled_for = excluded.scheduled_for, status = 'pending', error = null;

  insert into public.notification_jobs(organization_id, appointment_id, recipient_customer_id, kind, scheduled_for)
  values (a.organization_id, a.id, a.customer_id, 'reminder_2h', greatest(now(), a.starts_at - interval '2 hours'))
  on conflict (appointment_id, kind) where appointment_id is not null
  do update set scheduled_for = excluded.scheduled_for, status = 'pending', error = null;

  -- Staff-facing counterpart to 'confirmation'. Only queued if the staff
  -- row has a linked user account (profile_id) — an unclaimed/placeholder
  -- staff row has nobody to notify.
  select s.profile_id into v_staff_profile from public.staff s where s.id = a.staff_id;
  if v_staff_profile is not null then
    insert into public.notification_jobs(organization_id, appointment_id, recipient_user_id, kind, scheduled_for)
    values (a.organization_id, a.id, v_staff_profile, 'confirmation_staff', now())
    on conflict (appointment_id, kind) where appointment_id is not null do nothing;
  end if;

end;
$$;

grant execute on function public.queue_appointment_notifications(uuid) to anon, authenticated;


-- Called by reschedule_appointment() after it moves an appointment. Reuses
-- queue_appointment_notifications() to refresh reminder_24h/reminder_2h
-- against the (now updated) starts_at — fixing the stale-reminder bug as a
-- side effect — then queues a dedicated 'reschedule'/'reschedule_staff'
-- notification, which DO UPDATE (not DO NOTHING): if the same appointment
-- is rescheduled again later, it should notify again, not silently no-op
-- against the first reschedule's already-sent row.
create or replace function public.queue_reschedule_notifications(p_appointment uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
  v_staff_profile uuid;
begin

  select * into a from public.appointments where id = p_appointment;
  if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;

  perform public.queue_appointment_notifications(p_appointment);

  insert into public.notification_jobs(organization_id, appointment_id, recipient_customer_id, kind, scheduled_for)
  values (a.organization_id, a.id, a.customer_id, 'reschedule', now())
  on conflict (appointment_id, kind) where appointment_id is not null
  do update set scheduled_for = excluded.scheduled_for, status = 'pending', sent_at = null, error = null;

  select s.profile_id into v_staff_profile from public.staff s where s.id = a.staff_id;
  if v_staff_profile is not null then
    insert into public.notification_jobs(organization_id, appointment_id, recipient_user_id, kind, scheduled_for)
    values (a.organization_id, a.id, v_staff_profile, 'reschedule_staff', now())
    on conflict (appointment_id, kind) where appointment_id is not null
    do update set scheduled_for = excluded.scheduled_for, status = 'pending', sent_at = null, error = null;
  end if;

end;
$$;

grant execute on function public.queue_reschedule_notifications(uuid) to authenticated;


-- Same body as 0019_fix_variable_alias_collision.sql, plus the one new
-- line queuing reschedule notifications after the appointment is moved.
create or replace function public.reschedule_appointment(
  p_appointment uuid,
  p_new_start timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_appt record;
  v_tz text;
  v_date date;
  v_slot_end timestamptz;
begin

  select appt.*, aps.service_id, s.duration_min into v_appt
  from public.appointments appt
  join public.appointment_services aps on aps.appointment_id = appt.id
  join public.services s on s.id = aps.service_id
  where appt.id = p_appointment
  limit 1
  for update;

  if not found then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(
    v_appt.organization_id,
    array['owner','manager','receptionist','staff']
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if v_appt.status in ('completed','cancelled','no_show') then
    raise exception 'INVALID_APPOINTMENT_STATUS';
  end if;

  select coalesce(timezone, 'UTC') into v_tz from public.organizations where id = v_appt.organization_id;

  v_date := (p_new_start at time zone v_tz)::date;

  if not exists (
    select 1 from public.get_available_slots(v_appt.staff_id, v_appt.service_id, v_date, v_appt.location_id) s
    where s.starts_at = p_new_start
  ) then
    raise exception 'SLOT_NOT_AVAILABLE';
  end if;

  v_slot_end := p_new_start + make_interval(mins => v_appt.duration_min);

  update public.appointments
  set starts_at = p_new_start, ends_at = v_slot_end, updated_by = auth.uid()
  where id = p_appointment;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_appt.organization_id, auth.uid(), 'reschedule', 'appointment', p_appointment, jsonb_build_object('starts_at', p_new_start, 'ends_at', v_slot_end));

  perform public.queue_reschedule_notifications(p_appointment);

end;
$$;

grant execute on function public.reschedule_appointment(uuid, timestamptz) to authenticated;
