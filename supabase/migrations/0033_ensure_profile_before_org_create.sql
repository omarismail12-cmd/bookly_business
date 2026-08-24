-- Bug: brand-new signups hit
-- "insert or update on table organization_members violates foreign key
-- constraint organization_members_user_id_fkey ... Key (user_id)=(...) is
-- not present in table profiles" the moment they call
-- create_organization_for_current_user right after signup.
--
-- The profiles row is supposed to come from the on_auth_user_created
-- trigger (0001_foundation.sql) firing on insert into auth.users, in the
-- same transaction GoTrue uses to create the account. That should make a
-- missing profile row impossible by the time a session exists — but live
-- environments can drift from the migrations folder (a trigger created by
-- an early migration doesn't get automatically reconciled if it was ever
-- dropped/edited by hand, e.g. via the SQL editor). Whatever the exact
-- cause, create_organization_for_current_user (and anything else that
-- writes organization_members for auth.uid()) shouldn't have a hard
-- dependency on trigger timing/existence for its own correctness.
--
-- Fix in two parts:
-- 1) Re-assert the trigger so it's guaranteed present after this migration
--    runs, even if it was missing.
-- 2) Make create_organization_for_current_user self-healing: upsert the
--    caller's profile row itself before referencing it, so the function
--    no longer depends on the trigger having run at all.

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_profile();

create or replace function public.create_organization_for_current_user(p_name text,p_slug text,p_timezone text default 'UTC') returns uuid
language plpgsql security definer set search_path=public as $$
declare v_org uuid; begin
 if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
 insert into public.profiles(id) values(auth.uid()) on conflict(id) do nothing;
 insert into public.organizations(name,slug,timezone,created_by,updated_by) values(p_name,p_slug,p_timezone,auth.uid(),auth.uid()) returning id into v_org;
 insert into public.organization_members(organization_id,user_id,role,status,created_by,updated_by) values(v_org,auth.uid(),'owner','active',auth.uid(),auth.uid());
 update public.profiles set full_name=coalesce(full_name, split_part(coalesce((select email from auth.users where id=auth.uid()),''),'@',1)), updated_at=now() where id=auth.uid();
 insert into public.locations(organization_id,name,timezone,created_by,updated_by) values(v_org,'Main Location',p_timezone,auth.uid(),auth.uid());
 return v_org;
end $$;
