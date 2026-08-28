-- Closes two gaps confirmed live this session via direct API calls as a
-- real staff account against a real org:
--
-- 1) appointments_select (0008_security_storage_booking.sql) was
--    `organization_id in (current_org_ids())` — org-wide for any active
--    member, including staff. staff_today_page.dart only ever filters to
--    `.eq('staff_id', ownStaffId)` client-side; nothing enforced it
--    server-side. Live-tested: querying appointments as a staff login with
--    no staff_id filter returned all of the org's appointments, including
--    other staff members' and their customers' names.
--
--    KNOWN, ACCEPTED SIDE EFFECT: calendar_page.dart's own doc comment
--    says "the full Calendar is still reachable from the nav rail for
--    anyone who wants the admin view" (staff included), and
--    Permission.manageCalendar returns true for every business role,
--    staff included. Both rely on the same unrestricted read this
--    migration removes. After this, a staff account opening Calendar will
--    see only their own appointments, not the org-wide view the comment
--    describes — narrower than what manageCalendar currently implies.
--    Applying this exactly as requested; flagging the inconsistency
--    rather than silently also rewriting Permission.manageCalendar or
--    calendar_page.dart, which nobody asked for.
--
-- 2) change_queue_status (0010_features_completion.sql) allowed
--    array['owner','manager','receptionist','staff'] — but
--    Permission.manageQueue is `role != AppRole.staff`. Live-tested: a
--    staff account successfully called it (204). Removing 'staff' from
--    the allowed roles brings server-side enforcement in line with the
--    client-side permission that already claims to restrict this.
--
-- Run after 0001..0041.

drop policy if exists appointments_select on public.appointments;

create policy appointments_select
on public.appointments
for select
using (
  organization_id in (
    select organization_id from public.organization_members
    where user_id = auth.uid() and status = 'active' and role in ('owner','manager','receptionist')
  )
  or exists (
    select 1 from public.staff s
    where s.id = appointments.staff_id
      and s.organization_id = appointments.organization_id
      and s.profile_id = auth.uid()
  )
);

create or replace function public.change_queue_status(p_queue uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
begin

  if p_status not in ('waiting','called','in_service','completed','cancelled') then
    raise exception 'INVALID_QUEUE_STATUS';
  end if;

  select organization_id into v_org from public.queue_entries where id = p_queue for update;
  if v_org is null then raise exception 'QUEUE_NOT_FOUND'; end if;

  if not public.has_org_role(v_org, array['owner','manager','receptionist']) then
    raise exception 'FORBIDDEN';
  end if;

  update public.queue_entries set status = p_status, updated_at = now() where id = p_queue;

  perform public.recalculate_queue_wait(v_org);

end;
$$;

grant execute on function public.change_queue_status(uuid, text) to authenticated;
