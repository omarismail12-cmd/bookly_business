-- Critical fix, verified live: queue_appointment_notifications() has been
-- completely broken since migration 0007. Its ON CONFLICT (appointment_id,
-- kind) clauses don't repeat the partial index's WHERE predicate
-- (notification_jobs_appointment_kind_unique is `... WHERE appointment_id
-- IS NOT NULL`), so Postgres cannot infer a matching arbiter index and
-- throws 42P10 ("there is no unique or exclusion constraint matching the
-- ON CONFLICT specification"). Since create_booking() and
-- create_public_booking() both call this function inside the same
-- transaction as the appointment insert, and neither wraps that specific
-- call in an exception handler, this error propagates and rolls back the
-- entire booking — confirmed by actually calling create_booking() against
-- the live database and hitting exactly this error. Every booking attempt
-- through the real app has been failing since 0007 was applied.
-- Run after 0001..0013.

create or replace function public.queue_appointment_notifications(p_appointment uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
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

end;
$$;

grant execute on function public.queue_appointment_notifications(uuid) to anon, authenticated;
