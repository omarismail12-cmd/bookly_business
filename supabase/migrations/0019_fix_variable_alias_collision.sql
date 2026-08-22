-- 0017 tried to fix cancel_appointment()/reschedule_appointment() by
-- adding `if not found` after the SELECT INTO, but that wasn't the actual
-- bug — verified by calling the function via raw SQL (bypassing PostgREST
-- entirely), which showed the error happens *during* the SELECT INTO
-- itself, not the check afterward. The real cause: the PL/pgSQL record
-- variable is named `a`, and the query inside the same function *also*
-- uses `a` as the table alias for `appointments a`. `select a.*, ... into
-- a` is ambiguous between "expand the SQL alias a's columns" and
-- "reference the PL/pgSQL variable a" — Postgres resolves it to the
-- variable, which is always unassigned at that point in its own
-- assignment statement, so the error fires unconditionally, not just on a
-- zero-row match. Fixed for real this time by renaming the PL/pgSQL
-- variable so it can never collide with a SQL alias in its own function
-- body. Verified with `supabase db query` (raw SQL, no PostgREST caching
-- involved) before and after.
-- Run after 0001..0018.

create or replace function public.cancel_appointment(p_appointment uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_appt record;
begin

  select appt.*, s.cancellation_window_min into v_appt
  from public.appointments appt
  join public.appointment_services aps on aps.appointment_id = appt.id
  join public.services s on s.id = aps.service_id
  where appt.id = p_appointment
  limit 1;

  if not found then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(v_appt.organization_id, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  if v_appt.starts_at - now() < make_interval(mins => coalesce(v_appt.cancellation_window_min, 120)) then
    raise exception 'CANCELLATION_WINDOW_PASSED';
  end if;

  update public.appointments set status = 'cancelled', updated_by = auth.uid() where id = p_appointment;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (v_appt.organization_id, auth.uid(), 'cancel', 'appointment', p_appointment, jsonb_build_object('status', 'cancelled'));

end;
$$;

grant execute on function public.cancel_appointment(uuid) to authenticated;


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

end;
$$;

grant execute on function public.reschedule_appointment(uuid, timestamptz) to authenticated;
