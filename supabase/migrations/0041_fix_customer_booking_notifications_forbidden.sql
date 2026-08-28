-- Fixes a confirmed, live-reproduced bug: every signed-in customer's
-- booking attempt through create_public_booking() failed with FORBIDDEN,
-- because it calls queue_appointment_notifications() at the end of the
-- same transaction, and that function's guard was:
--
--   if auth.uid() is not null and not has_org_role(a.organization_id,
--     array['owner','manager','receptionist','staff']) then
--     raise exception 'FORBIDDEN';
--   end if;
--
-- This assumes any authenticated caller must be a business-side member of
-- the appointment's own org. A signed-in customer is authenticated but —
-- by design (see AppRole.customer's doc comment in app_role.dart) — never
-- an organization_members row for ANY org. So this check fired for every
-- signed-in customer booking, rolled back the whole transaction (raising
-- inside a plpgsql function aborts the caller's transaction), and no
-- appointment was ever created.
--
-- Verified live this session: anonymous booking against a real org
-- succeeded (200, real appointment id); the identical booking signed in
-- as a customer failed with this exact FORBIDDEN, on this exact function.
--
-- Fix: the check's real intent (this function is anon+authenticated
-- grantable, so it needs a guard against one business's staff injecting
-- notification jobs into an org they don't belong to) only applies to
-- authenticated callers who ARE business members of *some* org. A caller
-- with zero organization_members rows anywhere — i.e. a customer — was
-- never the threat this guarded against, so it's now exempted explicitly
-- instead of being caught by the same authenticated-implies-business-user
-- assumption that broke customer booking.
--
-- Run after 0001..0040.

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

  if auth.uid() is not null
    and exists(select 1 from public.organization_members where user_id = auth.uid() and status = 'active')
    and not public.has_org_role(a.organization_id, array['owner','manager','receptionist','staff'])
  then
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
