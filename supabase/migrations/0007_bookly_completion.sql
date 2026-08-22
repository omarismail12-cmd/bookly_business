-- Bookly completion migration.
-- Run AFTER 0001..0006. This migration adds public customer booking,
-- atomic queue numbering, role management, and stronger booking validation.

create unique index if not exists queue_entries_org_day_number
on public.queue_entries (organization_id, ((created_at at time zone 'UTC')::date), queue_number);

create or replace function public.set_member_role(p_org uuid,p_user uuid,p_role text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_role not in ('manager','receptionist','staff') then raise exception 'INVALID_ROLE'; end if;
  if not public.has_org_role(p_org,array['owner']) then raise exception 'FORBIDDEN'; end if;
  if not exists(select 1 from auth.users where id=p_user) then raise exception 'USER_NOT_FOUND'; end if;
  insert into public.organization_members(organization_id,user_id,role,status,created_by,updated_by)
  values(p_org,p_user,p_role,'active',auth.uid(),auth.uid())
  on conflict(organization_id,user_id) do update set role=excluded.role,status='active',updated_by=auth.uid(),updated_at=now();
end $$;
grant execute on function public.set_member_role(uuid,uuid,text) to authenticated;

create or replace function public.add_walk_in(p_customer uuid,p_service uuid,p_staff uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_number int; v_id uuid; v_day date;
begin
  select organization_id into v_org from public.customers where id=p_customer and deleted_at is null;
  if v_org is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;
  if not public.has_org_role(v_org,array['owner','manager','receptionist','staff']) then raise exception 'FORBIDDEN'; end if;
  if not exists(select 1 from public.services where id=p_service and organization_id=v_org and deleted_at is null) then raise exception 'SERVICE_NOT_FOUND'; end if;
  if p_staff is not null and not exists(select 1 from public.staff where id=p_staff and organization_id=v_org and status='active' and deleted_at is null) then raise exception 'STAFF_NOT_FOUND'; end if;
  v_day := (now() at time zone coalesce((select timezone from public.organizations where id=v_org),'UTC'))::date;
  perform pg_advisory_xact_lock(hashtextextended(v_org::text||v_day::text,0));
  select coalesce(max(queue_number),0)+1 into v_number
  from public.queue_entries
  where organization_id=v_org and (created_at at time zone coalesce((select timezone from public.organizations where id=v_org),'UTC'))::date=v_day;
  insert into public.queue_entries(organization_id,customer_id,service_id,staff_id,queue_number,estimated_wait_min)
  values(v_org,p_customer,p_service,p_staff,v_number,0) returning id into v_id;
  return v_id;
end $$;
grant execute on function public.add_walk_in(uuid,uuid,uuid) to authenticated;

create or replace function public.create_public_booking(
  p_slug text,p_customer_name text,p_customer_email text,p_customer_phone text,
  p_service uuid,p_staff uuid,p_starts_at timestamptz,p_location uuid default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_customer uuid; v_id uuid; v_duration int; v_price bigint; v_deposit bigint; v_end timestamptz; v_tz text;
begin
  select id,timezone into v_org,v_tz from public.organizations where slug=p_slug and status='active' and deleted_at is null;
  if v_org is null then raise exception 'BUSINESS_NOT_FOUND'; end if;
  if length(trim(coalesce(p_customer_name,''))) < 2 then raise exception 'CUSTOMER_NAME_REQUIRED'; end if;
  if p_customer_email is null and p_customer_phone is null then raise exception 'CUSTOMER_CONTACT_REQUIRED'; end if;
  select organization_id,duration_min,price_minor,deposit_required_minor into v_org,v_duration,v_price,v_deposit from public.services where id=p_service and organization_id=v_org and deleted_at is null;
  if v_duration is null then raise exception 'SERVICE_NOT_FOUND'; end if;
  if not exists(select 1 from public.staff where id=p_staff and organization_id=v_org and status='active' and deleted_at is null) then raise exception 'STAFF_NOT_FOUND'; end if;
  if not exists(select 1 from public.staff_services where staff_id=p_staff and service_id=p_service) then raise exception 'STAFF_CANNOT_PERFORM_SERVICE'; end if;
  v_end:=p_starts_at+make_interval(mins=>v_duration);
  if not exists(select 1 from public.get_available_slots(p_staff,p_service,(p_starts_at at time zone coalesce(v_tz,'UTC'))::date,p_location) s where s.starts_at=p_starts_at) then raise exception 'SLOT_NOT_AVAILABLE'; end if;
  select id into v_customer from public.customers where organization_id=v_org and deleted_at is null and ((p_customer_email is not null and lower(email)=lower(trim(p_customer_email))) or (p_customer_phone is not null and phone=trim(p_customer_phone))) order by created_at limit 1;
  if v_customer is null then
    insert into public.customers(organization_id,name,phone,email) values(v_org,trim(p_customer_name),nullif(trim(p_customer_phone),''),nullif(trim(p_customer_email),'')) returning id into v_customer;
  else
    update public.customers set name=trim(p_customer_name),phone=coalesce(nullif(trim(p_customer_phone),''),phone),email=coalesce(nullif(trim(p_customer_email),''),email),updated_at=now() where id=v_customer;
  end if;
  insert into public.appointments(organization_id,customer_id,staff_id,location_id,status,starts_at,ends_at,source,deposit_required_minor,notes) values(v_org,v_customer,p_staff,p_location,'confirmed',p_starts_at,v_end,'online',v_deposit,'PUBLIC_BOOKING') returning id into v_id;
  insert into public.appointment_services(appointment_id,service_id,price_minor,duration_min) values(v_id,p_service,v_price,v_duration);
  perform public.queue_appointment_notifications(v_id);
  return v_id;
exception when exclusion_violation then raise exception 'SLOT_ALREADY_BOOKED';
end $$;
grant execute on function public.create_public_booking(text,text,text,text,uuid,uuid,timestamptz,uuid) to anon,authenticated;

-- Make report helper explicitly tenant-safe even when called directly.
create or replace function public.report_dashboard(p_org uuid,p_from timestamptz,p_to timestamptz) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare r jsonb;
begin
  if not public.has_org_role(p_org,array['owner','manager','receptionist','staff']) then raise exception 'FORBIDDEN'; end if;
  select jsonb_build_object(
    'appointments',(select count(*) from appointments where organization_id=p_org and starts_at>=p_from and starts_at<p_to),
    'completed',(select count(*) from appointments where organization_id=p_org and status='completed' and starts_at>=p_from and starts_at<p_to),
    'cancelled',(select count(*) from appointments where organization_id=p_org and status='cancelled' and starts_at>=p_from and starts_at<p_to),
    'no_show',(select count(*) from appointments where organization_id=p_org and status='no_show' and starts_at>=p_from and starts_at<p_to),
    'revenue_minor',coalesce((select sum(amount_minor) from payments where organization_id=p_org and type in ('payment','deposit') and status='completed' and created_at>=p_from and created_at<p_to),0),
    'customers',(select count(*) from customers where organization_id=p_org and created_at>=p_from and created_at<p_to)
  ) into r; return r;
end $$;
grant execute on function public.report_dashboard(uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.change_queue_status(p_queue uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare v_org uuid;
begin
  if p_status not in ('waiting','called','in_service','completed','cancelled') then raise exception 'INVALID_QUEUE_STATUS'; end if;
  select organization_id into v_org from queue_entries where id=p_queue for update;
  if v_org is null then raise exception 'QUEUE_NOT_FOUND'; end if;
  if not public.has_org_role(v_org,array['owner','manager','receptionist','staff']) then raise exception 'FORBIDDEN'; end if;
  update queue_entries set status=p_status,updated_at=now() where id=p_queue;
end $$;
grant execute on function public.change_queue_status(uuid,text) to authenticated;

create or replace function public.set_member_role_by_email(p_org uuid,p_email text,p_role text)
returns void language plpgsql security definer set search_path=public as $$
declare v_user uuid;
begin
  if not public.has_org_role(p_org,array['owner']) then raise exception 'FORBIDDEN'; end if;
  select id into v_user from auth.users where lower(email)=lower(trim(p_email)) limit 1;
  if v_user is null then raise exception 'USER_NOT_FOUND'; end if;
  perform public.set_member_role(p_org,v_user,p_role);
end $$;
grant execute on function public.set_member_role_by_email(uuid,text,text) to authenticated;
create unique index if not exists working_hours_staff_weekday_unique on public.working_hours(staff_id,weekday);
create unique index if not exists staff_breaks_staff_weekday_unique on public.staff_breaks(staff_id,weekday);

create unique index if not exists notification_jobs_appointment_kind_unique
on public.notification_jobs(appointment_id,kind)
where appointment_id is not null;

create or replace function public.queue_appointment_notifications(p_appointment uuid) returns void language plpgsql security definer set search_path=public as $$
declare a record;
begin
  select * into a from public.appointments where id=p_appointment;
  if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  if auth.uid() is not null and not public.has_org_role(a.organization_id,array['owner','manager','receptionist','staff']) then raise exception 'FORBIDDEN'; end if;
  insert into public.notification_jobs(organization_id,appointment_id,recipient_customer_id,kind,scheduled_for) values(a.organization_id,a.id,a.customer_id,'confirmation',now()) on conflict (appointment_id,kind) do nothing;
  insert into public.notification_jobs(organization_id,appointment_id,recipient_customer_id,kind,scheduled_for) values(a.organization_id,a.id,a.customer_id,'reminder_24h',greatest(now(),a.starts_at-interval '24 hours')) on conflict (appointment_id,kind) do update set scheduled_for=excluded.scheduled_for,status='pending',error=null;
  insert into public.notification_jobs(organization_id,appointment_id,recipient_customer_id,kind,scheduled_for) values(a.organization_id,a.id,a.customer_id,'reminder_2h',greatest(now(),a.starts_at-interval '2 hours')) on conflict (appointment_id,kind) do update set scheduled_for=excluded.scheduled_for,status='pending',error=null;
end $$;
grant execute on function public.queue_appointment_notifications(uuid) to anon,authenticated;

create or replace function public.handle_new_profile() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name) values(new.id,new.raw_user_meta_data->>'full_name')
  on conflict(id) do update set full_name=coalesce(public.profiles.full_name,excluded.full_name),updated_at=now();
  return new;
end $$;

create or replace function public.change_appointment_status(p_appointment uuid,p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_old text; v_customer uuid;
begin
  if p_status not in ('pending','confirmed','checked_in','in_service','completed','cancelled','no_show') then raise exception 'INVALID_STATUS'; end if;
  select organization_id,status,customer_id into v_org,v_old,v_customer from public.appointments where id=p_appointment for update;
  if v_org is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  if not public.has_org_role(v_org,array['owner','manager','receptionist','staff']) then raise exception 'FORBIDDEN'; end if;
  if v_old=p_status then return; end if;
  update public.appointments set status=p_status,updated_by=auth.uid() where id=p_appointment;
  if p_status='no_show' then update public.customers set no_show_count=no_show_count+1,updated_at=now() where id=v_customer; end if;
  if p_status='completed' then update public.customers set last_visit_at=now(),updated_at=now() where id=v_customer; end if;
  insert into public.audit_logs(organization_id,user_id,action,entity,entity_id,old_data,new_data)
  values(v_org,auth.uid(),'status_change','appointment',p_appointment,jsonb_build_object('status',v_old),jsonb_build_object('status',p_status));
end $$;
grant execute on function public.change_appointment_status(uuid,text) to authenticated;

create or replace function public.record_payment(p_idempotency uuid,p_appointment uuid,p_amount bigint,p_method text,p_type text default 'payment') returns uuid language plpgsql security definer set search_path=public as $$
declare v_payment uuid; v_org uuid;
begin
  if p_amount<=0 then raise exception 'INVALID_AMOUNT'; end if;
  select organization_id into v_org from public.appointments where id=p_appointment;
  if v_org is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  if not public.has_org_role(v_org,array['owner','manager','receptionist']) then raise exception 'FORBIDDEN'; end if;
  select id into v_payment from public.payments where idempotency_key=p_idempotency::text;
  if v_payment is not null then return v_payment; end if;
  insert into public.payments(organization_id,appointment_id,amount_minor,method,type,idempotency_key,created_by)
  values(v_org,p_appointment,p_amount,p_method,p_type,p_idempotency::text,auth.uid()) returning id into v_payment;
  if p_type='deposit' then update public.appointments set deposit_paid_minor=deposit_paid_minor+p_amount where id=p_appointment; end if;
  insert into public.audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(v_org,auth.uid(),'payment','payment',v_payment,jsonb_build_object('amount_minor',p_amount,'type',p_type));
  return v_payment;
end $$;
grant execute on function public.record_payment(uuid,uuid,bigint,text,text) to authenticated;

create or replace function public.cancel_appointment(p_appointment uuid) returns void language plpgsql security definer set search_path=public as $$
declare a record;
begin
  select a.*,s.cancellation_window_min into a from public.appointments a join public.appointment_services aps on aps.appointment_id=a.id join public.services s on s.id=aps.service_id where a.id=p_appointment limit 1;
  if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  if not public.has_org_role(a.organization_id,array['owner','manager','receptionist']) then raise exception 'FORBIDDEN'; end if;
  if a.starts_at-now() < make_interval(mins=>coalesce(a.cancellation_window_min,120)) then raise exception 'CANCELLATION_WINDOW_PASSED'; end if;
  update public.appointments set status='cancelled',updated_by=auth.uid() where id=p_appointment;
  insert into public.audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(a.organization_id,auth.uid(),'cancel','appointment',p_appointment,jsonb_build_object('status','cancelled'));
end $$;
grant execute on function public.cancel_appointment(uuid) to authenticated;

create or replace function public.reschedule_appointment(p_appointment uuid,p_new_start timestamptz) returns void language plpgsql security definer set search_path=public as $$
declare a record; v_end timestamptz;
begin
  select a.*,aps.service_id,s.duration_min into a from public.appointments a join public.appointment_services aps on aps.appointment_id=a.id join public.services s on s.id=aps.service_id where a.id=p_appointment limit 1;
  if a.id is null then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  if not public.has_org_role(a.organization_id,array['owner','manager','receptionist']) then raise exception 'FORBIDDEN'; end if;
  v_end=p_new_start+make_interval(mins=>a.duration_min);
  if exists(select 1 from public.appointments x where x.id<>p_appointment and x.staff_id=a.staff_id and x.deleted_at is null and x.status in ('pending','confirmed','checked_in','in_service') and p_new_start<x.ends_at and v_end>x.starts_at) then raise exception 'SLOT_ALREADY_BOOKED'; end if;
  update public.appointments set starts_at=p_new_start,ends_at=v_end,version=version+1,updated_by=auth.uid() where id=p_appointment;
  insert into public.audit_logs(organization_id,user_id,action,entity,entity_id,new_data) values(a.organization_id,auth.uid(),'reschedule','appointment',p_appointment,jsonb_build_object('starts_at',p_new_start,'ends_at',v_end));
end $$;
grant execute on function public.reschedule_appointment(uuid,timestamptz) to authenticated;

drop policy if exists appointments_select on public.appointments;
create policy appointments_select on public.appointments for select using (
  public.has_org_role(organization_id,array['owner','manager','receptionist'])
  or (
    public.has_org_role(organization_id,array['staff'])
    and exists(select 1 from public.staff s where s.id=appointments.staff_id and s.profile_id=auth.uid())
  )
);

create or replace function public.set_member_role_by_email(p_org uuid,p_email text,p_role text)
returns void language plpgsql security definer set search_path=public as $$
declare v_user uuid; v_name text;
begin
  if not public.has_org_role(p_org,array['owner']) then raise exception 'FORBIDDEN'; end if;
  select id,coalesce(raw_user_meta_data->>'full_name',split_part(email,'@',1)) into v_user,v_name from auth.users where lower(email)=lower(trim(p_email)) limit 1;
  if v_user is null then raise exception 'USER_NOT_FOUND'; end if;
  perform public.set_member_role(p_org,v_user,p_role);
  if p_role='staff' then
    insert into public.staff(organization_id,profile_id,display_name,status,created_by,updated_by)
    values(p_org,v_user,v_name,'active',auth.uid(),auth.uid())
    on conflict do nothing;
  end if;
end $$;
grant execute on function public.set_member_role_by_email(uuid,text,text) to authenticated;
create unique index if not exists staff_org_profile_unique on public.staff(organization_id,profile_id) where profile_id is not null;

create or replace function public.get_my_memberships()
returns table(organization_id uuid,organization_name text,role text,status text,timezone text)
language sql stable security definer set search_path=public as $$
  select m.organization_id,o.name,m.role,m.status,o.timezone
  from public.organization_members m join public.organizations o on o.id=m.organization_id
  where m.user_id=auth.uid();
$$;
grant execute on function public.get_my_memberships() to authenticated;
