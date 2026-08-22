-- Critical fix, verified live: cancel_appointment() and
-- reschedule_appointment() both do `select ... into a from appointments a
-- join appointment_services aps ... where a.id = p_appointment` and then
-- test `if a.id is null`. When zero rows match (appointment doesn't
-- exist), PL/pgSQL leaves the record variable `a` completely *unassigned*
-- rather than assigned-with-nulls — accessing `a.id` on an unassigned
-- record raises "record \"a\" is not assigned yet" (Postgres error 55000)
-- instead of evaluating the intended NULL check. Confirmed by calling both
-- RPCs live with a nonexistent appointment id: both threw the raw Postgres
-- error instead of the intended 'APPOINTMENT_NOT_FOUND' — exposing
-- internal error detail to the client instead of a clean message.
-- Fix: check PL/pgSQL's `FOUND` variable (correctly set by SELECT INTO
-- even when the record itself stays unassigned) immediately after the
-- query, before touching any field of `a`.
-- Run after 0001..0016.

create or replace function public.cancel_appointment(p_appointment uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
begin

  select a.*, s.cancellation_window_min into a
  from public.appointments a
  join public.appointment_services aps on aps.appointment_id = a.id
  join public.services s on s.id = aps.service_id
  where a.id = p_appointment
  limit 1;

  if not found then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(a.organization_id, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  if a.starts_at - now() < make_interval(mins => coalesce(a.cancellation_window_min, 120)) then
    raise exception 'CANCELLATION_WINDOW_PASSED';
  end if;

  update public.appointments set status = 'cancelled', updated_by = auth.uid() where id = p_appointment;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (a.organization_id, auth.uid(), 'cancel', 'appointment', p_appointment, jsonb_build_object('status', 'cancelled'));

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
  a record;
  v_tz text;
  v_date date;
  v_slot_end timestamptz;
begin

  select a.*, aps.service_id, s.duration_min into a
  from public.appointments a
  join public.appointment_services aps on aps.appointment_id = a.id
  join public.services s on s.id = aps.service_id
  where a.id = p_appointment
  limit 1
  for update;

  if not found then
    raise exception 'APPOINTMENT_NOT_FOUND';
  end if;

  if not public.has_org_role(
    a.organization_id,
    array['owner','manager','receptionist','staff']
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if a.status in ('completed','cancelled','no_show') then
    raise exception 'INVALID_APPOINTMENT_STATUS';
  end if;

  select coalesce(timezone, 'UTC') into v_tz from public.organizations where id = a.organization_id;

  v_date := (p_new_start at time zone v_tz)::date;

  if not exists (
    select 1 from public.get_available_slots(a.staff_id, a.service_id, v_date, a.location_id) s
    where s.starts_at = p_new_start
  ) then
    raise exception 'SLOT_NOT_AVAILABLE';
  end if;

  v_slot_end := p_new_start + make_interval(mins => a.duration_min);

  update public.appointments
  set starts_at = p_new_start, ends_at = v_slot_end, updated_by = auth.uid()
  where id = p_appointment;

  insert into public.audit_logs(organization_id, user_id, action, entity, entity_id, new_data)
  values (a.organization_id, auth.uid(), 'reschedule', 'appointment', p_appointment, jsonb_build_object('starts_at', p_new_start, 'ends_at', v_slot_end));

end;
$$;

grant execute on function public.reschedule_appointment(uuid, timestamptz) to authenticated;
