-- Phase 7 follow-up. set_member_role_by_email() (0007) already auto-creates
-- a NEW staff row (profile_id = the assigned user) whenever the 'staff'
-- role is assigned by email — a mechanism missed when 0031 was written.
-- That auto-create is fine for "brand new hire, no staff row yet", but it
-- means the realistic use of link_staff_to_user_by_email() — attaching a
-- login to a staff row the owner ALREADY created and has been scheduling
-- against (e.g. "Maya" added via Add staff, given a login later) — collided
-- with staff_org_profile_unique(organization_id, profile_id): her
-- profile_id was already claimed by the auto-created duplicate row from
-- role assignment, so linking the real row failed outright with a raw
-- 23505 constraint-violation error instead of doing anything useful.
--
-- Fix: before linking, if that profile_id is already attached to a
-- *different* staff row in the same org, unlink it there first. The
-- account moves to the row the owner is pointing at; the stale duplicate
-- becomes an ordinary unlinked staff row the owner can rename, reuse, or
-- remove like any other, instead of a silent, permanently-orphaned one.

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

  if not exists (
    select 1 from public.organization_members
    where organization_id = v_org and user_id = v_user and status = 'active'
  ) then
    raise exception 'USER_NOT_A_MEMBER';
  end if;

  update public.staff
  set profile_id = null, updated_at = now(), updated_by = auth.uid()
  where organization_id = v_org and profile_id = v_user and id <> p_staff;

  update public.staff
  set profile_id = v_user, updated_at = now(), updated_by = auth.uid()
  where id = p_staff and organization_id = v_org;

end;
$$;

grant execute on function public.link_staff_to_user_by_email(uuid, text) to authenticated;
