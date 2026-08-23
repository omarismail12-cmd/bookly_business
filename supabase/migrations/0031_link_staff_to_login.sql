-- Phase 7: staff.profile_id currently has no way to be set except a raw DB
-- update. StaffPage lets an owner create a bare staff row (display name
-- only, no login) and, separately, assign a business role to an email
-- (organization_members via set_member_role_by_email) — but nothing ever
-- links the two. Without that link:
--   - staff_today_page.dart resolves the signed-in staff member by
--     `staff.profile_id = auth.uid()`; finding no row, it just renders an
--     empty schedule with no error, not an obvious "you're not linked yet".
--   - change_appointment_status()'s staff-self clause (0026) requires that
--     same match, so an unlinked staff-role account can't even manage its
--     own appointments via the RPC.
-- The role is functionally broken without this link, and there was no way
-- to set it short of a manual database edit.

create or replace function public.link_staff_to_user_by_email(
  p_staff uuid,
  p_email text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_user uuid;
begin

  select organization_id into v_org from public.staff where id = p_staff and deleted_at is null;
  if v_org is null then
    raise exception 'STAFF_NOT_FOUND';
  end if;

  if not public.has_org_role(v_org, array['owner']) then
    raise exception 'FORBIDDEN';
  end if;

  select id into v_user from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_user is null then
    raise exception 'USER_NOT_FOUND';
  end if;

  -- Must already be a member of this org (any role — an owner who also
  -- takes bookings themselves is a real scenario, so this deliberately
  -- doesn't require role = 'staff' specifically). Linking an account with
  -- no membership at all would be inert (has_org_role would still fail
  -- everywhere that matters) but would silently look "done" in the UI
  -- while doing nothing useful, so it's rejected with a clear reason
  -- instead.
  if not exists (
    select 1 from public.organization_members
    where organization_id = v_org and user_id = v_user and status = 'active'
  ) then
    raise exception 'USER_NOT_A_MEMBER';
  end if;

  update public.staff
  set profile_id = v_user, updated_at = now(), updated_by = auth.uid()
  where id = p_staff and organization_id = v_org;

end;
$$;

grant execute on function public.link_staff_to_user_by_email(uuid, text) to authenticated;
