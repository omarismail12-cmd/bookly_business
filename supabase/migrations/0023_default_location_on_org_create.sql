-- New businesses need at least one location before staff can be scheduled
-- or bookings taken (get_available_slots/create_booking accept a location
-- but appointments.location_id is nullable — a default location just makes
-- the Locations screen non-empty from the start). Mirrors what
-- seed_demo_data_for_current_user() already does for demo orgs.
create or replace function public.create_organization_for_current_user(p_name text,p_slug text,p_timezone text default 'UTC') returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; begin
 if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
 insert into public.organizations(name,slug,timezone,created_by,updated_by) values(p_name,p_slug,p_timezone,auth.uid(),auth.uid()) returning id into v_org;
 insert into public.organization_members(organization_id,user_id,role,status,created_by,updated_by) values(v_org,auth.uid(),'owner','active',auth.uid(),auth.uid());
 update public.profiles set full_name=coalesce(full_name, split_part(coalesce((select email from auth.users where id=auth.uid()),''),'@',1)), updated_at=now() where id=auth.uid();
 insert into public.locations(organization_id,name,timezone,created_by,updated_by) values(v_org,'Main Location',p_timezone,auth.uid(),auth.uid());
 return v_org;
end $$;
